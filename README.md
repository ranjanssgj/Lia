# Lia - AI Desktop Companion (Linux/Godot)

**[Lia](https://github.com/ranjanssgj/Lia)** is an intelligent, offline desktop companion built for Linux (Arch/Hyprland). Unlike standard desktop pets, Lia uses a local Large Language Model (Llama 3.2 via Ollama) to converse, react to emotions, and roam the screen freely while maintaining transparency and click-through capabilities.

## 🛠 Tech Stack
* **Engine:** Godot 4.3 (Compatibility Mode / OpenGL)
* **Language:** GDScript
* **AI Backend:** Ollama (Llama 3.2:1b)
* **Format:** VRM (Anime Character) & Mixamo Animations
* **OS Target:** Linux (Arch + Hyprland), compatible with X11/Wayland.

---

## 🏗 Architecture Layers
The project is built on four distinct layers:
1.  **The Stage:** Transparent window management & OS integration.
2.  **The Body:** VRM rendering & Smart Hitboxes.
3.  **The Brain:** HTTP Bridge to local AI & Emotion Parsing.
4.  **The Behavior:** Finite State Machine (Idle, Roaming, Hiding).

---
Development Documentation is available [here](https://github.com/ranjanssgj/Documentation/blob/main/Lia.md)
