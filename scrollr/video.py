"""
Video: informazioni, fotogrammi e audio letti con PyAV (che include FFmpeg), scrittura delle pagine in MP4.
Niente Qt qui: i fotogrammi escono come immagini Pillow, l'audio come PCM a 16 bit stereo.
"""
import threading
from array import array
from fractions import Fraction
from typing import Dict, List, Optional

from PIL import Image

try:
    import av
except ImportError:  # Senza PyAV i video non compaiono tra i formati accettati (vedi config)
    av = None

# Uscita pensata per i caroselli social (Instagram: slide video fino a 60 s, 30 fps, H.264 + AAC)
VIDEO_FPS = 30
VIDEO_MAX_SECONDS = 60.0
VIDEO_MAX_SIDE = 1920        # Lato lungo massimo dell'MP4: oltre, i social ricomprimono comunque
AUDIO_RATE = 44100
_BYTES_PER_SAMPLE = 4        # s16 stereo: 2 canali × 2 byte

_ROTATE = {90: Image.Transpose.ROTATE_90, -90: Image.Transpose.ROTATE_270,
           180: Image.Transpose.ROTATE_180, -180: Image.Transpose.ROTATE_180}

_info_cache: Dict[str, dict] = {}
_info_lock = threading.Lock()


def _stream_start(stream) -> float:
    return float(stream.start_time * stream.time_base) if stream.start_time is not None else 0.0


def _frame_to_pil(frame, max_side: Optional[int]) -> Image.Image:
    """Fotogramma → immagine RGB, ridotta a max_side sul lato lungo e girata come va mostrata (telefoni)."""
    w, h = frame.width, frame.height
    k = min(1.0, max_side / max(w, h)) if max_side else 1.0
    img = frame.to_image(width=max(2, round(w * k)), height=max(2, round(h * k)), interpolation="BILINEAR")
    rot = _ROTATE.get(round(frame.rotation or 0))
    return img.transpose(rot) if rot is not None else img


def video_info(path: str) -> dict:
    """Durata (s), dimensioni come appare (rotazione inclusa), fps e presenza dell'audio. In cache."""
    with _info_lock:
        cached = _info_cache.get(path)
    if cached is not None:
        return dict(cached)
    with av.open(path) as c:
        vs = c.streams.video[0]
        if vs.duration:
            duration = float(vs.duration * vs.time_base)
        elif c.duration:
            duration = c.duration / 1_000_000
        else:
            duration = 0.0
        fps = float(vs.average_rate) if vs.average_rate else float(VIDEO_FPS)
        width, height = vs.codec_context.width, vs.codec_context.height
        for frame in c.decode(vs):
            width, height = frame.width, frame.height
            if round(frame.rotation or 0) in (90, -90):
                width, height = height, width
            break
        info = {"duration": max(0.0, duration), "width": width, "height": height, "fps": fps,
                "audio": bool(c.streams.audio)}
    with _info_lock:
        _info_cache[path] = info
    return dict(info)


def grab_frame(path: str, t: float = 0.0, max_side: Optional[int] = None) -> Image.Image:
    """Il fotogramma al secondo `t` (dall'inizio del video)."""
    reader = FrameReader(path, max_side)
    try:
        img = reader.frame_at(t)
    finally:
        reader.close()
    if img is None:
        raise ValueError("nessun fotogramma leggibile")
    return img


class FrameReader:
    """
    Lettura in sequenza, per la riproduzione e l'esportazione: frame_at(t) va avanti decodificando
    e torna indietro (o salta lontano) con una ricerca. Restituisce l'ultimo fotogramma con tempo ≤ t.
    """

    def __init__(self, path: str, max_side: Optional[int] = None):
        self.path = path
        self.max_side = max_side
        self.container = av.open(path)
        self.stream = self.container.streams.video[0]
        self.stream.thread_type = "AUTO"
        self.start = _stream_start(self.stream)
        fps = float(self.stream.average_rate) if self.stream.average_rate else float(VIDEO_FPS)
        self._eps = 0.5 / max(1.0, fps)
        self._iter = None
        self._cur = None       # (tempo, fotogramma) mostrato ora
        self._next = None      # Fotogramma già decodificato ma non ancora arrivato
        self._image = None     # Conversione in Pillow del fotogramma attuale (fatta una volta)
        self._eof = False

    def _time(self, frame) -> float:
        return (frame.time - self.start) if frame.time is not None else 0.0

    def _seek(self, t: float):
        target = int((self.start + max(0.0, t)) / self.stream.time_base)
        try:
            self.container.seek(target, stream=self.stream, backward=True)
        except av.error.FFmpegError:
            self.container.seek(0, stream=self.stream)
        self._iter = self.container.decode(self.stream)
        self._cur = self._next = self._image = None
        self._eof = False

    def _pull(self):
        if self._next is None and not self._eof:
            try:
                frame = next(self._iter)
                self._next = (self._time(frame), frame)
            except (StopIteration, av.error.FFmpegError):
                self._eof = True

    def frame_at(self, t: float) -> Optional[Image.Image]:
        if self._iter is None or self._cur is None or t < self._cur[0] - self._eps or t > self._cur[0] + 2.0:
            self._seek(t)
        while True:
            self._pull()
            if self._next is None or self._next[0] > t + self._eps:
                break
            self._cur, self._next, self._image = self._next, None, None
        if self._cur is None and self._next is not None:
            # Prima del primo fotogramma (o ricerca finita poco dopo): si usa il primo disponibile
            self._cur, self._next, self._image = self._next, None, None
        if self._cur is None:
            return None
        if self._image is None:
            self._image = _frame_to_pil(self._cur[1], self.max_side)
        return self._image

    def close(self):
        try:
            self.container.close()
        except Exception:
            pass


# ---------- Audio ----------
def read_audio(path: str, start: float, end: float) -> Optional[bytes]:
    """Audio da `start` a `end` secondi, PCM s16 stereo a AUDIO_RATE. None se il video non ha audio."""
    with av.open(path) as c:
        if not c.streams.audio:
            return None
        a = c.streams.audio[0]
        s0 = _stream_start(a)
        try:
            c.seek(int((s0 + max(0.0, start)) / a.time_base), stream=a, backward=True)
        except av.error.FFmpegError:
            pass
        resampler = av.AudioResampler(format="s16", layout="stereo", rate=AUDIO_RATE)
        out = bytearray()
        first_t = None
        try:
            for frame in c.decode(a):
                ft = (frame.time - s0) if frame.time is not None else 0.0
                if first_t is None:
                    first_t = ft
                for rf in resampler.resample(frame):
                    out += bytes(rf.planes[0])[:rf.samples * _BYTES_PER_SAMPLE]
                if ft > end + 0.5:
                    break
        except av.error.FFmpegError:
            pass  # Audio rovinato in fondo: si tiene quello letto
        for rf in resampler.resample(None):
            out += bytes(rf.planes[0])[:rf.samples * _BYTES_PER_SAMPLE]
    if first_t is None:
        return None
    skip = max(0, round((start - first_t) * AUDIO_RATE)) * _BYTES_PER_SAMPLE
    take = max(0, round((end - start) * AUDIO_RATE)) * _BYTES_PER_SAMPLE
    pcm = bytes(out[skip:skip + take])
    # Audio più corto del video: si completa col silenzio, così il giro successivo resta a tempo
    return pcm + bytes(take - len(pcm))


def loop_audio(pcm: bytes, seconds: float) -> bytes:
    """Ripete l'audio (i video più corti ricominciano da capo) fino a `seconds` secondi."""
    need = round(seconds * AUDIO_RATE) * _BYTES_PER_SAMPLE
    if not pcm:
        return bytes(need)
    return (pcm * (need // len(pcm) + 1))[:need]


def mix_audio(tracks: List[bytes]) -> bytes:
    """Somma più tracce della stessa lunghezza (s16), tagliando i picchi che sforano."""
    if len(tracks) == 1:
        return tracks[0]
    arrays = [array("h", t) for t in tracks]
    return array("h", (max(-32768, min(32767, sum(v))) for v in zip(*arrays))).tobytes()


# ---------- Scrittura MP4 ----------
def output_size(w: float, h: float) -> tuple:
    """Dimensioni dell'MP4 per una pagina w × h: lato lungo al massimo VIDEO_MAX_SIDE, misure pari (H.264)."""
    k = min(1.0, VIDEO_MAX_SIDE / max(w, h))
    return max(2, int(w * k) // 2 * 2), max(2, int(h * k) // 2 * 2)


def _video_codec() -> str:
    for name in ("libx264", "h264_mf", "h264_videotoolbox", "mpeg4"):
        if name in av.codecs_available:
            try:
                av.codec.Codec(name, "w")
                return name
            except Exception:
                continue
    return "mpeg4"


class Mp4Writer:
    """MP4 H.264 + AAC: si aggiungono i fotogrammi (RGBA) uno alla volta, l'audio segue in parallelo."""

    def __init__(self, path: str, width: int, height: int, fps: int = VIDEO_FPS, audio: Optional[bytes] = None):
        self.width, self.height, self.fps = width, height, fps
        self.container = av.open(path, "w", format="mp4", options={"movflags": "+faststart"})
        codec = _video_codec()
        # «fast»: circa metà tempo di «medium»; a CRF 18 la differenza non si vede (e i social ricomprimono)
        options = {"crf": "18", "preset": "fast"} if codec == "libx264" else {}
        self.video = self.container.add_stream(codec, rate=fps, options=options)
        self.video.width, self.video.height = width, height
        self.video.pix_fmt = "yuv420p"
        if codec != "libx264":
            self.video.bit_rate = 12_000_000
        self.audio = None
        self._pcm = audio or b""
        self._pcm_pos = 0  # Campioni già scritti
        if audio:
            self.audio = self.container.add_stream("aac", rate=AUDIO_RATE)
            self.audio.layout = "stereo"
            self.audio.bit_rate = 192_000
        self._n = 0

    def add_frame(self, rgba: bytes):
        frame = av.VideoFrame.from_bytes(rgba, self.width, self.height, format="rgba")
        frame.pts = self._n
        frame.time_base = Fraction(1, self.fps)
        for packet in self.video.encode(frame):
            self.container.mux(packet)
        self._n += 1
        self._write_audio_until(self._n / self.fps)

    def _write_audio_until(self, seconds: float, final: bool = False):
        if self.audio is None:
            return
        total = len(self._pcm) // _BYTES_PER_SAMPLE
        upto = total if final else min(total, round(seconds * AUDIO_RATE))
        chunk = 1024
        while self._pcm_pos < upto:
            n = min(chunk, upto - self._pcm_pos)
            if n < chunk and not final:
                break  # Pezzo incompleto: aspetta il fotogramma dopo
            data = self._pcm[self._pcm_pos * _BYTES_PER_SAMPLE:(self._pcm_pos + n) * _BYTES_PER_SAMPLE]
            af = av.AudioFrame(format="s16", layout="stereo", samples=n)
            af.planes[0].update(data + bytes(af.planes[0].buffer_size - len(data)))
            af.sample_rate = AUDIO_RATE
            af.pts = self._pcm_pos
            af.time_base = Fraction(1, AUDIO_RATE)
            for packet in self.audio.encode(af):
                self.container.mux(packet)
            self._pcm_pos += n

    def close(self):
        for packet in self.video.encode(None):
            self.container.mux(packet)
        if self.audio is not None:
            self._write_audio_until(0, final=True)
            for packet in self.audio.encode(None):
                self.container.mux(packet)
        self.container.close()

    def abort(self):
        try:
            self.container.close()
        except Exception:
            pass
