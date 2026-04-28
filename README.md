# 🎯 Asset Thumbnailer (Godot 4.x)

A powerful editor plugin for generating high-quality icons from 3D scenes and meshes — directly inside Godot.

Designed for RPGs, survival games, and any project that needs clean, consistent item thumbnails.

---

## ✨ Features

* 🖼️ Real-time preview inside the editor
* 🎮 Supports `.tscn`, `.glb`, `.gltf`, `.fbx`, `.blend`, `.mesh`
* 📏 Multiple export sizes (128, 256, 512, 1024, 2048)
* 🎯 Auto-scale & auto-center models
* 🔄 Full camera control:

  * Rotate (spin object)
  * Tilt (top-down angle)
  * Roll (left/right slant)
  * Zoom
* 🎨 Background options:

  * Transparent
  * Custom color
* 📦 Batch workflow:

  * Load entire folder
  * Next / Previous navigation
* 📝 Custom export filename
* ⚡ Instant preview updates (no lag)
* ✅ Export directly to PNG

---

## 📸 Preview

![Thumbnailer UI](https://raw.githubusercontent.com/mclever7/Godot-Thumbnailer/refs/heads/main/img/interface_2.png)

---

![Thumbnailer UI](https://raw.githubusercontent.com/mclever7/Godot-Thumbnailer/refs/heads/main/img/interface_1.png)

---
## 📦 Installation

### From Godot Asset Library

1. Open the **Asset Library** tab in the editor
2. Search for **Asset Thumbnailer**
3. Click **Download** → **Install**

---

### Manual Installation

1. Download this repository
2. Copy the folder:

```
addons/asset_thumbnailer/
```

into your project:

```
res://addons/
```

3. Enable the plugin:

```
Project → Project Settings → Plugins → Enable "Asset Thumbnailer"
```

---

## 🚀 Usage

1. Open the plugin panel (right dock)
2. Add a file or folder
3. Adjust:

   * Camera angle (tilt / roll)
   * Rotation
   * Zoom
   * Background
4. Preview updates instantly
5. Click **Export**

---

## 🎮 Controls Explained

| Control | Description                              |
| ------- | ---------------------------------------- |
| Rotate  | Spins the object                         |
| Tilt    | Camera up/down angle                     |
| Roll    | Left/right slant (like rotating a photo) |
| Zoom    | Distance from object                     |

---

## 🧠 How It Works

* Automatically normalizes object scale
* Centers model pivot
* Frames object using bounding box
* Renders via `SubViewport`
* Exports as PNG

---

## 📁 Output

Images are saved to:

```
res://addons/asset_thumbnailer/generated_icons/
```

(Or your custom path)

---

## ⚠️ Notes

* Very small or very large models are auto-scaled
* Complex scenes may take slightly longer to render
* Ensure meshes are properly imported

---

## 🛠️ Requirements

* Godot 4.x (tested on 4.5)
* No external dependencies

---

## 🧩 Roadmap

* [ ] Drag-to-rotate with mouse
* [ ] HDRI / sky lighting
* [ ] Auto-angle per item type (weapons, armor, etc.)
* [ ] Batch export presets

---

## 🤝 Contributing

Feel free to open issues or submit pull requests.

---

## 📄 License

GPL-3.0 License

---

## ⭐ Support

If this tool helps your project, consider giving it a ⭐ on GitHub!
