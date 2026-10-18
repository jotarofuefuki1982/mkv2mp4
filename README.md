# mkv2mp4

Converts `.mkv` files into `.mp4` files that **every Jellyfin client can direct play**
(web browsers, Roku, Fire TV, Apple TV, Android TV), so the server doesn't have to
transcode while you watch.

```
mkv2mp4 /media/incoming /media/jellyfin/Movies
```

For every `.mkv` under the source directory:

1. `DEST/<same subfolders>/<name>.mp4` is created.
2. Once that succeeds, the original is renamed in place to `<name>.converted.mkv`.
   Originals are **never deleted**.
3. Files already named `*.converted.mkv` are skipped on later runs, so it's safe to
   re-run (e.g. from cron). To convert a file again, rename it back to `.mkv`.

Subfolders are mirrored, so `Show/Season 01/Show S01E01.mkv` becomes
`DEST/Show/Season 01/Show S01E01.mp4`, the layout Jellyfin expects.

## What the output looks like

| | Result |
|---|---|
| Video | H.264 High, 8-bit. Video that is already compatible H.264 is **copied** (seconds, no quality loss). HEVC, 10-bit, AV1, MPEG-2, VC-1 etc. are re-encoded. HDR is tone-mapped to SDR. Interlaced video is deinterlaced. |
| Audio | Track 1 is **AAC stereo** (default), which plays everywhere. AAC/AC3/E-AC3/MP3 tracks are copied. DTS, TrueHD, FLAC etc. surround tracks become **AC3 5.1**, so surround is kept. All languages are kept. |
| Subtitles | Text subtitles (SRT/ASS/WebVTT) are embedded as MP4 text tracks, or written as sidecar files with `--external-subs`. Image subtitles (PGS/VobSub) can't be stored in MP4 and are dropped unless you use `--burn-subs`. |
| Other | Chapters and metadata are kept. Faststart is enabled so playback starts instantly. |

Encoding uses the GPU when one is available (NVIDIA NVENC, then Intel/AMD VAAPI;
VideoToolbox on Apple Silicon Macs), otherwise the CPU (x264). Run with `--dry-run` first to see exactly what will
happen to each file.

## Install

Requires Python 3.8+ and ffmpeg. All three methods below handle those for you.

**Arch**

```
cd packaging/arch && makepkg -si
```

**Ubuntu / Debian**

```
./packaging/debian/build-deb.sh
sudo apt install ./dist/mkv2mp4_*_all.deb
```

**macOS** (needs [Homebrew](https://brew.sh))

```
./install.sh                   # ffmpeg via Homebrew, then asks for sudo to install to /usr/local/bin
./install.sh --uninstall
```

The Python 3 that comes with Apple's developer tools (which Homebrew installs)
is enough.

**Any distro (simple script)**

```
./install.sh                   # installs to /usr/local/bin, and ffmpeg via pacman/apt
./install.sh --uninstall
```

### GPU encoding (optional but much faster)

* **Ubuntu:** add yourself to the `render` group, then log out and back in:
  `sudo usermod -aG render $USER`. Install the VAAPI driver:
  `mesa-va-drivers` (AMD) or `intel-media-va-driver` (Intel).
* **Arch:** AMD works out of the box with mesa. Intel needs `intel-media-driver`
  (or `libva-intel-driver` on pre-Broadwell chips).
* **macOS:** Apple Silicon Macs use the VideoToolbox hardware encoder
  automatically; nothing to install. Intel Macs use x264 (VideoToolbox's
  constant-quality mode, which mkv2mp4 relies on, needs Apple Silicon).
* **Mac Pro running Ubuntu:** the AMD FirePro/Radeon cards may or may not expose
  a VAAPI H.264 encoder depending on generation. mkv2mp4 tests this at startup
  and falls back to x264 if needed. The Xeon CPUs are fast at x264, so try
  `-j 2` or `-j 3` to keep all cores busy.

Use `mkv2mp4 -n SRC DEST` to see which encoder was chosen.

Full documentation: `man mkv2mp4` (installed by all three methods above).

## Options

```
mkv2mp4 SOURCE DEST [options]

  -n, --dry-run         show the plan for every file, convert nothing
  -j, --jobs N          convert N files in parallel (default 1)
  -e, --encoder E       auto | vaapi | nvenc | videotoolbox | x264   (default auto)
  -q, --quality N       lower = better/bigger. x264 CRF / NVENC CQ / VAAPI QP;
                        VideoToolbox quality is 100 - 2N (default 20)
      --preset P        x264 preset (default medium; slower = smaller files)
      --max-height PX   downscale taller video, e.g. 1080 (old Fire Sticks/Rokus
                        can't play 4K H.264)
      --external-subs   write text subs as Name.eng.srt / Name.eng.ass sidecars
      --burn-subs       burn one image subtitle (forced > default > first) into the video
      --no-rename       don't rename originals
      --overwrite       replace existing .mp4s in DEST (otherwise they're skipped)
      --no-recursive    only the top level of SOURCE
      --log FILE        default ~/.local/state/mkv2mp4/mkv2mp4.log
```

SOURCE can also be a single `.mkv` file.

## Notes

* Conversions are written to a hidden `.name.mp4.part` file and renamed only on
  success. A crash or Ctrl-C never leaves a broken `.mp4`, and the original
  keeps its name so the next run retries it.
* If SOURCE is inside a Jellyfin library, Jellyfin will also list the
  `.converted.mkv` files. Keep the source folder outside your libraries, or
  move the originals off once you're happy with the results.
* Exit status: 0 = all good, 1 = some files failed, 2 = usage error, 130 = interrupted.
