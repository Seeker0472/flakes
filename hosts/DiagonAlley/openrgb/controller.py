"""OpenRGB scene controller with persistent user preferences for DiagonAlley."""

from __future__ import annotations

import argparse
import copy
import fcntl
import json
import math
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Self

PROFILE_NAME = "quickshell.json"
EFFECTS_PLUGIN_NAME = "OpenRGB Effects Plugin"
HEADER = struct.Struct("<4sIII")
PLUGIN_LIST_PACKET = 200
PLUGIN_SPECIFIC_PACKET = 201
LOAD_EFFECTS_PROFILE_PACKET = 23
MEMORY_CONTROLLER_NAME = "ENE DRAM"
MEMORY_ONLY_SCENES = frozenset({"audioPulse", "audioSpectrum", "lightning"})


def slider(key: str, label: str, minimum: int, maximum: int, step: int = 1, unit: str = "%") -> dict[str, Any]:
    return {
        "key": key,
        "label": label,
        "type": "slider",
        "min": minimum,
        "max": maximum,
        "step": step,
        "unit": unit,
    }


SCENES: dict[str, dict[str, Any]] = {
    "solid": {
        "name": "Solid",
        "description": "A quiet, uniform color",
        "category": "Calm",
        "icon": "circle",
        "preview": ["#F5C2E7"],
        "defaults": {"color": "#F5C2E7"},
        "params": [{"key": "color", "label": "Color", "type": "color"}],
    },
    "spectrum": {
        "name": "Spectrum",
        "description": "A synchronized color cycle",
        "category": "Flow",
        "icon": "spectrum",
        "preview": ["#F38BA8", "#F9E2AF", "#A6E3A1", "#89DCEB", "#CBA6F7"],
        "defaults": {"duration": 60, "saturation": 100},
        "params": [
            slider("duration", "Cycle duration", 12, 180, 6, "s"),
            slider("saturation", "Saturation", 0, 100),
        ],
    },
    "breathing": {
        "name": "Breathing",
        "description": "Colors fade gently in and out",
        "category": "Calm",
        "icon": "breathing",
        "preview": ["#89DCEB", "#F5C2E7"],
        "defaults": {"duration": 8, "random": False, "colors": ["#89DCEB", "#F5C2E7"]},
        "params": [
            {"key": "colors", "label": "Colors", "type": "colors", "minItems": 1, "maxItems": 4},
            slider("duration", "Breath duration", 2, 30, 1, "s"),
            {"key": "random", "label": "Random colors", "type": "toggle"},
        ],
    },
    "aurora": {
        "name": "Aurora",
        "description": "A broad, custom gradient wave",
        "category": "Flow",
        "icon": "aurora",
        "preview": ["#32E6B4", "#69A7FF", "#B56BFF"],
        "defaults": {
            "colors": ["#32E6B4", "#69A7FF", "#B56BFF", "#32E6B4"],
            "speed": 18,
            "width": 130,
            "direction": "forward",
        },
        "params": [
            {"key": "colors", "label": "Gradient", "type": "colors", "minItems": 2, "maxItems": 4},
            slider("speed", "Flow speed", 1, 80, 1, "%"),
            slider("width", "Gradient width", 20, 200, 10, "%"),
            {"key": "direction", "label": "Direction", "type": "direction"},
        ],
    },
    "rainbow": {
        "name": "Rainbow Flow",
        "description": "A spatial rainbow moving across zones",
        "category": "Flow",
        "icon": "rainbow",
        "preview": ["#F38BA8", "#F9E2AF", "#A6E3A1", "#89DCEB", "#CBA6F7"],
        "defaults": {"speed": 6, "wavelength": 10, "direction": "forward"},
        "params": [
            slider("speed", "Flow speed", 1, 40, 1, "%"),
            slider("wavelength", "Wavelength", 1, 30, 1, ""),
            {"key": "direction", "label": "Direction", "type": "direction"},
        ],
    },
    "starlight": {
        "name": "Starlight",
        "description": "Soft points appearing over a dark sky",
        "category": "Calm",
        "icon": "stars",
        "preview": ["#030711", "#FFFFFF", "#BBD8FF"],
        "defaults": {
            "colors": ["#FFFFFF", "#BBD8FF"],
            "background": "#030711",
            "density": 22,
            "fade": 55,
        },
        "params": [
            {"key": "colors", "label": "Star colors", "type": "colors", "minItems": 1, "maxItems": 4},
            {"key": "background", "label": "Background", "type": "color"},
            slider("density", "Density", 10, 90),
            slider("fade", "Fade", 1, 100),
        ],
    },
    "ember": {
        "name": "Ember",
        "description": "Warm sparks flickering over a low glow",
        "category": "Calm",
        "icon": "ember",
        "preview": ["#180200", "#FF2A16", "#FF6A24", "#FFD06A"],
        "defaults": {
            "colors": ["#FFD06A", "#FF6A24", "#FF2A16"],
            "background": "#180200",
            "intensity": 45,
            "density": 42,
            "speed": 30,
        },
        "params": [
            {"key": "colors", "label": "Ember colors", "type": "colors", "minItems": 1, "maxItems": 4},
            {"key": "background", "label": "Background glow", "type": "color"},
            slider("intensity", "Glow", 0, 100),
            slider("density", "Density", 10, 90),
            slider("speed", "Flicker speed", 1, 100),
        ],
    },
    "lightning": {
        "name": "Lightning",
        "description": "Memory-only flashes with controlled decay",
        "category": "Flow",
        "icon": "lightning",
        "preview": ["#07101F", "#C7DCFF"],
        "defaults": {"color": "#C7DCFF", "frequency": 5, "intensity": 90, "decay": 18},
        "params": [
            {"key": "color", "label": "Flash color", "type": "color"},
            slider("frequency", "Frequency", 1, 40),
            slider("intensity", "Intensity", 10, 100),
            slider("decay", "Decay", 2, 60, 1, ""),
        ],
    },
    "audioPulse": {
        "name": "Audio Pulse",
        "description": "Memory-only color pulses; other lights stay dark",
        "category": "Audio",
        "icon": "audio",
        "preview": ["#89DCEB", "#F5C2E7", "#F9E2AF"],
        "defaults": {"colorMode": "vivid", "sensitivity": 100, "decay": 50, "hueShift": 0},
        "params": [
            {
                "key": "colorMode",
                "label": "Color mode",
                "type": "options",
                "choices": [
                    {"key": "vivid", "label": "Vivid"},
                    {"key": "dynamic", "label": "Dynamic"},
                    {"key": "mono", "label": "Mono"},
                ],
            },
            slider("sensitivity", "Sensitivity", 20, 200),
            slider("decay", "Color decay", 1, 99),
            slider("hueShift", "Hue shift", 0, 360, 10, "deg"),
        ],
    },
    "audioSpectrum": {
        "name": "Audio Spectrum",
        "description": "A frequency meter across the memory bars",
        "category": "Audio",
        "icon": "equalizer",
        "preview": ["#89DCEB", "#A6E3A1", "#F9E2AF", "#F38BA8"],
        "defaults": {"sensitivity": 100, "decay": 10, "spread": 70, "hue": 200},
        "params": [
            slider("sensitivity", "Sensitivity", 20, 200),
            slider("decay", "Meter decay", 1, 20, 1, ""),
            slider("spread", "Color spread", 10, 100),
            slider("hue", "Palette start", 0, 360, 10, "deg"),
        ],
    },
}


def default_state() -> dict[str, Any]:
    return {
        "power": True,
        "scene": "spectrum",
        "brightness": 100,
        "scenes": {key: copy.deepcopy(value["defaults"]) for key, value in SCENES.items()},
    }


def runtime_root() -> Path:
    configured = os.environ.get("OPENRGB_CONTROL_STATE_DIR")
    if configured:
        return Path(configured)
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        raise RuntimeError("XDG_RUNTIME_DIR is not set")
    return Path(runtime) / "openrgb-control"


def profile_dir(config_dir: Path) -> Path:
    return config_dir / "plugins" / "settings" / "effect-profiles"


def config_dir() -> Path:
    configured = os.environ.get("OPENRGB_CONTROL_EFFECTS_CONFIG_DIR")
    if configured:
        return Path(configured)
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        raise RuntimeError("XDG_RUNTIME_DIR is not set")
    return Path(runtime) / "openrgb-effects"


def state_path() -> Path:
    configured = os.environ.get("OPENRGB_CONTROL_STATE_DIR")
    if configured:
        return Path(configured) / "state.json"
    state_home = os.environ.get("XDG_STATE_HOME")
    return (Path(state_home) if state_home else Path.home() / ".local" / "state") / "openrgb-control" / "state.json"


def atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def normalize_color(value: Any) -> str:
    if not isinstance(value, str):
        raise ValueError("color must be a string")  # noqa: TRY004 - CLI input errors use one exception type.
    value = value.upper()
    if len(value) != 7 or value[0] != "#" or any(char not in "0123456789ABCDEF" for char in value[1:]):
        raise ValueError(f"invalid color: {value}")
    return value


def clamp_number(value: Any, minimum: int, maximum: int, step: int) -> int:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError("value must be a finite number")
    rounded = round((float(value) - minimum) / step) * step + minimum
    return max(minimum, min(maximum, int(rounded)))


def validate_setting(scene: str, key: str, value: Any) -> Any:
    spec = next((item for item in SCENES[scene]["params"] if item["key"] == key), None)
    if spec is None:
        raise ValueError(f"unknown {scene} setting: {key}")
    kind = spec["type"]
    if kind == "slider":
        return clamp_number(value, spec["min"], spec["max"], spec["step"])
    if kind == "toggle":
        if not isinstance(value, bool):
            raise ValueError(f"{key} must be a boolean")
        return value
    if kind == "direction":
        if value not in ("forward", "reverse"):
            raise ValueError("direction must be forward or reverse")
        return value
    if kind == "options":
        choices = {choice["key"] for choice in spec["choices"]}
        if value not in choices:
            raise ValueError(f"{key} must be one of: {', '.join(sorted(choices))}")
        return value
    if kind == "color":
        return normalize_color(value)
    if kind == "colors":
        if not isinstance(value, list) or not spec["minItems"] <= len(value) <= spec["maxItems"]:
            raise ValueError(f"{key} must contain {spec['minItems']} to {spec['maxItems']} colors")
        return [normalize_color(color) for color in value]
    raise ValueError(f"unsupported setting type: {kind}")


def normalize_state(value: Any) -> dict[str, Any]:
    state = default_state()
    if not isinstance(value, dict):
        return state
    scene = value.get("scene", state["scene"])
    if scene in SCENES:
        state["scene"] = scene
    if isinstance(value.get("power"), bool):
        state["power"] = value["power"]
    try:
        state["brightness"] = clamp_number(value.get("brightness", 100), 0, 100, 1)
    except ValueError:
        pass
    stored_scenes = value.get("scenes", {})
    if isinstance(stored_scenes, dict):
        for scene_id, defaults in state["scenes"].items():
            stored = stored_scenes.get(scene_id, {})
            if not isinstance(stored, dict):
                continue
            for key in defaults:
                if key in stored:
                    try:
                        defaults[key] = validate_setting(scene_id, key, stored[key])
                    except ValueError:
                        pass
    return state


def load_state() -> dict[str, Any]:
    target = state_path()
    try:
        with target.open(encoding="utf-8") as handle:
            return normalize_state(json.load(handle))
    except FileNotFoundError:
        # Import the old session-only state on the first run after upgrading.
        if os.environ.get("OPENRGB_CONTROL_STATE_DIR"):
            return default_state()
        try:
            with (runtime_root() / "state.json").open(encoding="utf-8") as handle:
                return normalize_state(json.load(handle))
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            return default_state()
    except (json.JSONDecodeError, OSError):
        return default_state()


def apply_patch(state: dict[str, Any], patch: Any) -> dict[str, Any]:
    if not isinstance(patch, dict):
        raise ValueError("patch must be a JSON object")  # noqa: TRY004 - CLI input errors use one exception type.
    allowed = {"scene", "power", "brightness", "settings", "scenes", "resetScene"}
    unknown = set(patch) - allowed
    if unknown:
        raise ValueError(f"unknown patch fields: {', '.join(sorted(unknown))}")
    result = copy.deepcopy(state)
    if "scene" in patch:
        if patch["scene"] not in SCENES:
            raise ValueError(f"unknown scene: {patch['scene']}")
        result["scene"] = patch["scene"]
        result["power"] = True
    if "power" in patch:
        if not isinstance(patch["power"], bool):
            raise ValueError("power must be a boolean")
        result["power"] = patch["power"]
    if "brightness" in patch:
        result["brightness"] = clamp_number(patch["brightness"], 0, 100, 1)
    if "scenes" in patch:
        if not isinstance(patch["scenes"], dict):
            raise ValueError("scenes must be a JSON object")
        unknown_scenes = set(patch["scenes"]) - set(SCENES)
        if unknown_scenes:
            raise ValueError(f"unknown scenes: {', '.join(sorted(unknown_scenes))}")
        for scene_id, settings in patch["scenes"].items():
            if not isinstance(settings, dict):
                raise ValueError(  # noqa: TRY004 - CLI input errors use one exception type.
                    f"{scene_id} settings must be a JSON object"
                )
            for key, value in settings.items():
                result["scenes"][scene_id][key] = validate_setting(scene_id, key, value)
    scene = result["scene"]
    if patch.get("resetScene") is True:
        result["scenes"][scene] = copy.deepcopy(SCENES[scene]["defaults"])
    elif "resetScene" in patch and patch["resetScene"] is not False:
        raise ValueError("resetScene must be a boolean")
    if "settings" in patch:
        if not isinstance(patch["settings"], dict):
            raise ValueError("settings must be a JSON object")
        for key, value in patch["settings"].items():
            result["scenes"][scene][key] = validate_setting(scene, key, value)
    return result


def rgb_int(color: str) -> int:
    color = normalize_color(color)
    red = int(color[1:3], 16)
    green = int(color[3:5], 16)
    blue = int(color[5:7], 16)
    return red | (green << 8) | (blue << 16)


def scaled_hex(color: str, brightness: int) -> str:
    color = normalize_color(color)
    scale = clamp_number(brightness, 0, 100, 1) / 100
    channels = [round(int(color[index : index + 2], 16) * scale) for index in (1, 3, 5)]
    return "".join(f"{channel:02X}" for channel in channels)


def zone_role(zone: dict[str, Any]) -> str:
    if zone["name"] == MEMORY_CONTROLLER_NAME:
        return "memory"
    if zone["zone_idx"] in (0, 1):
        return "addressable"
    return "accent"


def template_zones(target: str = "all", reverse: bool = False) -> list[dict[str, Any]]:
    roles = {
        "all": {"memory", "addressable", "accent"},
        "memory": {"memory"},
        "peripheral": {"addressable", "accent"},
    }
    if target not in roles:
        raise ValueError(f"unknown zone target: {target}")
    template = os.environ.get("OPENRGB_CONTROL_TEMPLATE")
    if not template:
        raise RuntimeError("OPENRGB_CONTROL_TEMPLATE is not set")
    with Path(template).open(encoding="utf-8") as handle:
        profile = json.load(handle)
    zones = [
        copy.deepcopy(zone)
        for zone in profile["Effects"][0]["ControllerZones"]
        if zone_role(zone) in roles[target]
    ]
    for zone in zones:
        zone["reverse"] = reverse
        zone["self_brightness"] = 100
    return zones


def audio_settings(sensitivity: int) -> dict[str, Any]:
    return {
        "audio_device": 0,
        "amplitude": sensitivity,
        "avg_mode": 0,
        "avg_size": 8,
        "window_mode": 1,
        "decay": 80,
        "filter_constant": 1.0,
        "nrml_ofst": 0.04,
        "nrml_scl": 0.5,
        "equalizer": [1.0] * 16,
    }


def effect(
    class_name: str,
    name: str,
    brightness: int,
    *,
    speed: int = 1,
    slider2: int = 1,
    colors: list[str] | None = None,
    custom: dict[str, Any] | None = None,
    random_colors: bool = False,
    reverse: bool = False,
    target: str = "all",
) -> dict[str, Any]:
    return {
        "EffectClassName": class_name,
        "CustomName": name,
        "FPS": 30,
        "Speed": speed,
        "Slider2Val": slider2,
        "RandomColors": random_colors,
        "AllowOnlyFirst": False,
        "Brightness": brightness,
        "Temperature": 0,
        "Tint": 0,
        "UserColors": [rgb_int(color) for color in (colors or [])],
        "CustomSettings": custom or {},
        "AutoStart": True,
        "ControllerZones": template_zones(target, reverse),
    }


def build_profile(state: dict[str, Any]) -> dict[str, Any]:
    if not state["power"] or state["brightness"] == 0 or state["scene"] == "solid":
        return {"version": 2, "Effects": []}

    scene = state["scene"]
    settings = state["scenes"][scene]
    brightness = state["brightness"]

    if scene == "spectrum":
        selected = effect(
            "SpectrumCycling",
            "Quickshell Spectrum",
            brightness,
            speed=max(1, min(100, round(360 / settings["duration"]))),
            custom={"saturation": round(settings["saturation"] * 2.55)},
        )
    elif scene == "breathing":
        selected = effect(
            "Breathing",
            "Quickshell Breathing",
            brightness,
            speed=max(10, min(200, round(math.pi * 100 / settings["duration"]))),
            random_colors=settings["random"],
            custom={"colors": [rgb_int(color) for color in settings["colors"]]},
        )
    elif scene == "aurora":
        selected = effect(
            "CustomGradientWave",
            "Quickshell Aurora",
            brightness,
            speed=settings["speed"],
            custom={
                "colors": [rgb_int(color) for color in settings["colors"]],
                "spread": settings["width"],
                "direction": 0,
                "height": 50,
                "width": 50,
            },
            reverse=settings["direction"] == "reverse",
        )
    elif scene == "rainbow":
        selected = effect(
            "RainbowWave",
            "Quickshell Rainbow Flow",
            brightness,
            speed=settings["speed"],
            slider2=settings["wavelength"],
            reverse=settings["direction"] == "reverse",
        )
    elif scene in ("starlight", "ember"):
        if scene == "starlight":
            colors = settings["colors"]
            background = settings["background"]
            density = settings["density"]
            fade = settings["fade"]
            background_brightness = 100
            name = "Quickshell Starlight"
        else:
            colors = settings["colors"]
            background = settings["background"]
            density = settings["density"]
            fade = settings["speed"]
            background_brightness = settings["intensity"]
            name = "Quickshell Ember"
        selected = effect(
            "StarryNight",
            name,
            brightness,
            custom={
                "starColors": [rgb_int(color) for color in colors],
                "starDensity": density,
                "backgroundColors": rgb_int(background),
                "fadeInSpeed": fade,
                "fadeOutSpeed": fade,
                "starOnTime": max(1, min(100, fade // 2)),
                "backColorBrightness": background_brightness,
            },
        )
    elif scene == "lightning":
        selected = effect(
            "Lightning",
            "Quickshell Lightning",
            round(brightness * settings["intensity"] / 100),
            speed=settings["frequency"],
            slider2=settings["decay"],
            colors=[settings["color"]],
            custom={"lightning_mode": 1},
            target="memory",
        )
    elif scene == "audioPulse":
        selected = effect(
            "AudioSync",
            "Quickshell Audio Pulse",
            brightness,
            custom={
                "fade_step": settings["decay"],
                "hue_shift": settings["hueShift"],
                "bypass_min": 0,
                "bypass_max": 256,
                "saturation_mode": {"vivid": 0, "dynamic": 1, "mono": 2}[settings["colorMode"]],
                "roll_mode": 1,
                "silent_color": False,
                "silent_color_value": 0,
                "audio_settings": audio_settings(settings["sensitivity"]),
            },
            target="memory",
        )
    elif scene == "audioSpectrum":
        selected = effect(
            "AudioVUMeter",
            "Quickshell Audio Spectrum",
            brightness,
            speed=settings["decay"],
            custom={
                "color_offset": settings["hue"],
                "color_spread": settings["spread"],
                "saturation": 255,
                "invert_hue": False,
                "audio_settings": audio_settings(settings["sensitivity"]),
            },
            target="memory",
        )
    else:
        raise ValueError(f"unsupported scene: {scene}")
    return {"version": 2, "Effects": [selected]}


def write_runtime_files(state: dict[str, Any], target_config: Path | None = None) -> None:
    target_config = target_config or config_dir()
    atomic_json(profile_dir(target_config) / PROFILE_NAME, build_profile(state))
    atomic_json(
        target_config / "plugins" / "settings" / "EffectSettings.json",
        {
            "fpscapture": 30,
            "fps": 30,
            "brightness": 100,
            "temperature": 0,
            "tint": 0,
            "startup_profile": PROFILE_NAME,
            "hide_unsupported": False,
            "prefer_random": False,
            "prefered_colors": [],
            "use_prefered_colors": False,
            "audio_settings": audio_settings(100),
        },
    )


def receive_exact(connection: socket.socket, size: int) -> bytes:
    chunks: list[bytes] = []
    remaining = size
    while remaining:
        chunk = connection.recv(remaining)
        if not chunk:
            raise ConnectionError("OpenRGB SDK connection closed unexpectedly")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def parse_string(data: bytes, offset: int) -> tuple[str, int]:
    if offset + 2 > len(data):
        raise ValueError("truncated OpenRGB plugin list")
    length = struct.unpack_from("<H", data, offset)[0]
    offset += 2
    if length < 1 or offset + length > len(data):
        raise ValueError("invalid OpenRGB plugin string length")
    raw = data[offset : offset + length]
    if raw[-1] != 0:
        raise ValueError("OpenRGB plugin string is not terminated")
    return raw[:-1].decode("utf-8"), offset + length


def parse_plugins(data: bytes) -> list[dict[str, Any]]:
    if len(data) < 6:
        raise ValueError("truncated OpenRGB plugin list")
    declared_size, count = struct.unpack_from("<IH", data)
    if declared_size != len(data):
        raise ValueError("invalid OpenRGB plugin list size")
    offset = 6
    plugins = []
    for _ in range(count):
        name, offset = parse_string(data, offset)
        description, offset = parse_string(data, offset)
        version, offset = parse_string(data, offset)
        if offset + 8 > len(data):
            raise ValueError("truncated OpenRGB plugin metadata")
        index, protocol = struct.unpack_from("<II", data, offset)
        offset += 8
        plugins.append(
            {
                "name": name,
                "description": description,
                "version": version,
                "index": index,
                "protocol": protocol,
            }
        )
    if offset != len(data):
        raise ValueError("unexpected data after OpenRGB plugin list")
    return plugins


def receive_effects_plugins(connection: socket.socket) -> list[dict[str, Any]]:
    connection.sendall(HEADER.pack(b"ORGB", 0, PLUGIN_LIST_PACKET, 0))
    magic, _device, packet, size = HEADER.unpack(receive_exact(connection, HEADER.size))
    if magic != b"ORGB" or packet != PLUGIN_LIST_PACKET:
        raise ValueError("unexpected OpenRGB plugin list response")
    if size > 1024 * 1024:
        raise ValueError("OpenRGB plugin list is unreasonably large")
    return parse_plugins(receive_exact(connection, size))


def server_controller_count(timeout: float = 0.5) -> int:
    with socket.create_connection(("127.0.0.1", 6742), timeout=timeout) as connection:
        connection.settimeout(timeout)
        connection.sendall(HEADER.pack(b"ORGB", 0, 0, 0))
        magic, _device, packet, size = HEADER.unpack(receive_exact(connection, HEADER.size))
        if magic != b"ORGB" or packet != 0 or size != 4:
            raise ValueError("invalid OpenRGB controller count response")
        return struct.unpack("<I", receive_exact(connection, size))[0]


def wait_for_server(timeout: float = 45) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            if server_controller_count() > 0:
                return
        except (OSError, ValueError, struct.error):
            pass
        time.sleep(0.25)
    raise RuntimeError("OpenRGB SDK did not detect any RGB controllers")


def load_effects_profile(host: str = "127.0.0.1", port: int = 6743, timeout: float = 1.5) -> None:
    with socket.create_connection((host, port), timeout=timeout) as connection:
        connection.settimeout(timeout)
        plugins = receive_effects_plugins(connection)
        plugin = next((item for item in plugins if item["name"] == EFFECTS_PLUGIN_NAME), None)
        if plugin is None:
            raise RuntimeError("OpenRGB Effects Plugin is not registered")
        if plugin["protocol"] < 2:
            raise RuntimeError("OpenRGB Effects Plugin SDK protocol is too old")
        encoded = PROFILE_NAME.encode("utf-8") + b"\0"
        data = struct.pack("<I", LOAD_EFFECTS_PROFILE_PACKET) + struct.pack("<H", len(encoded)) + encoded
        connection.sendall(HEADER.pack(b"ORGB", plugin["index"], PLUGIN_SPECIFIC_PACKET, len(data)) + data)


def systemd_unit_active(unit: str, *, user: bool = False) -> bool:
    systemctl = os.environ.get("OPENRGB_CONTROL_SYSTEMCTL", "systemctl")
    command = [systemctl]
    if user:
        command.append("--user")
    command.extend(["is-active", "--quiet", unit])
    try:
        return (
            subprocess.run(
                command,
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode
            == 0
        )
    except OSError:
        return False


def static_color(state: dict[str, Any]) -> str:
    if not state["power"] or state["brightness"] == 0:
        return "000000"
    return scaled_hex(state["scenes"]["solid"]["color"], state["brightness"])


def apply_static(state: dict[str, Any]) -> None:
    executable = os.environ.get("OPENRGB_CONTROL_OPENRGB", "openrgb")
    subprocess.run(
        [
            executable,
            "--client",
            "127.0.0.1:6742",
            "--nodetect",
            "--mode",
            "direct",
            "--color",
            static_color(state),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=8,
    )


def topology_overrides(state: dict[str, Any]) -> list[tuple[str, int | None, str]]:
    scene = state["scene"]
    if scene in MEMORY_ONLY_SCENES:
        controllers = {zone["name"] for zone in template_zones("peripheral")}
        return [(controller, None, "000000") for controller in sorted(controllers)]
    return []


def apply_topology_overrides(state: dict[str, Any]) -> None:
    executable = os.environ.get("OPENRGB_CONTROL_OPENRGB", "openrgb")
    for controller, zone, color in topology_overrides(state):
        command = [
            executable,
            "--client",
            "127.0.0.1:6742",
            "--nodetect",
            "--device",
            controller,
        ]
        if zone is not None:
            command.extend(["--zone", str(zone)])
        command.extend(["--mode", "direct", "--color", color])
        subprocess.run(
            command,
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=8,
        )


def is_static(state: dict[str, Any]) -> bool:
    return not state["power"] or state["brightness"] == 0 or state["scene"] == "solid"


def apply_runtime(state: dict[str, Any], *, fallback: bool) -> None:
    try:
        load_effects_profile()
        if is_static(state):
            apply_static(state)
        else:
            apply_topology_overrides(state)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
        if not fallback:
            raise
        systemctl = os.environ.get("OPENRGB_CONTROL_SYSTEMCTL", "systemctl")
        subprocess.run(
            [systemctl, "--user", "restart", "openrgb-effects.service"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=8,
        )


def wait_for_runtime(timeout: float = 10) -> None:
    deadline = time.monotonic() + timeout
    last_error: BaseException | None = None
    while time.monotonic() < deadline:
        try:
            load_effects_profile(timeout=0.5)
            return
        except (OSError, ValueError, RuntimeError) as error:
            last_error = error
            time.sleep(0.2)
    raise RuntimeError(f"OpenRGB Effects SDK did not become ready: {last_error}")


def public_state(state: dict[str, Any]) -> dict[str, Any]:
    current = state["scene"]
    openrgb_is_available = systemd_unit_active("openrgb.service")
    effects_is_available = systemd_unit_active("openrgb-effects.service", user=True)
    catalog = []
    for scene_id, scene in SCENES.items():
        catalog.append(
            {
                "id": scene_id,
                "name": scene["name"],
                "description": scene["description"],
                "category": scene["category"],
                "icon": scene["icon"],
                "params": scene["params"],
                "defaults": scene["defaults"],
                "preview": scene["preview"],
            }
        )
    return {
        "power": state["power"],
        "scene": current,
        "sceneName": SCENES[current]["name"],
        "brightness": state["brightness"],
        "settings": state["scenes"][current],
        "scenes": state["scenes"],
        "available": openrgb_is_available and effects_is_available,
        "openrgbAvailable": openrgb_is_available,
        "effectsAvailable": effects_is_available,
        "catalog": catalog,
    }


class StateLock:
    def __enter__(self) -> Self:
        root = runtime_root()
        root.mkdir(parents=True, exist_ok=True)
        self.handle = (root / "lock").open("a+")
        fcntl.flock(self.handle, fcntl.LOCK_EX)
        return self

    def __exit__(self, *_args: object) -> None:
        fcntl.flock(self.handle, fcntl.LOCK_UN)
        self.handle.close()


def emit(state: dict[str, Any]) -> None:
    print(json.dumps(public_state(state), separators=(",", ":")))


def command_status(_args: argparse.Namespace) -> None:
    emit(load_state())


def command_apply(args: argparse.Namespace) -> None:
    try:
        patch = json.loads(args.patch)
    except json.JSONDecodeError as error:
        raise ValueError(f"invalid patch JSON: {error.msg}") from error
    with StateLock():
        state = apply_patch(load_state(), patch)
        write_runtime_files(state)
        atomic_json(state_path(), state)
        apply_runtime(state, fallback=True)
    emit(state)


def command_reset(_args: argparse.Namespace) -> None:
    with StateLock():
        state = default_state()
        write_runtime_files(state)
        atomic_json(state_path(), state)
        apply_runtime(state, fallback=True)
    emit(state)


def command_prepare(args: argparse.Namespace) -> None:
    target = Path(args.config_dir)
    with StateLock():
        state = load_state()
        write_runtime_files(state, target)
        atomic_json(state_path(), state)


def command_restore(_args: argparse.Namespace) -> None:
    with StateLock():
        state = load_state()
        wait_for_runtime()
        if is_static(state):
            apply_static(state)
        else:
            apply_topology_overrides(state)


def command_wait_server(_args: argparse.Namespace) -> None:
    wait_for_server()


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)
    status = subparsers.add_parser("status", help="print the current state")
    status.set_defaults(handler=command_status)
    apply = subparsers.add_parser("apply", help="apply a JSON state patch")
    apply.add_argument("patch")
    apply.set_defaults(handler=command_apply)
    reset = subparsers.add_parser("reset", help="restore the declarative defaults")
    reset.set_defaults(handler=command_reset)
    prepare = subparsers.add_parser("prepare", help="prepare an Effects Plugin configuration directory")
    prepare.add_argument("config_dir")
    prepare.set_defaults(handler=command_prepare)
    restore = subparsers.add_parser("restore", help="restore static state after the service starts")
    restore.set_defaults(handler=command_restore)
    wait_server = subparsers.add_parser("wait-server", help="wait for the OpenRGB SDK and detected controllers")
    wait_server.set_defaults(handler=command_wait_server)
    return result


def main() -> int:
    try:
        args = parser().parse_args()
        args.handler(args)
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(json.dumps({"error": str(error)}, separators=(",", ":")), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
