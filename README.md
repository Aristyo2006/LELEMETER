![Flutter](https://img.shields.io/badge/Flutter-Framework-blue)
![Platform](https://img.shields.io/badge/Platform-Android-green)
![License](https://img.shields.io/badge/License-MIT-orange)



# 📸 LELEMETER

A simple **smartphone light meter** built with **Flutter** that measures ambient light using the device's **lux sensor** and converts it into useful exposure information for photography.

This project aims to turn a smartphone into a **portable light meter** for photographers and filmmakers.

---

## ✨ Features

* 📡 Real-time **Lux Meter** reading from the phone's ambient light sensor
* 🎛 Manual exposure settings:

  * ISO / ASA selection
  * Shutter Speed selection
  * Aperture (f-stop) selection
* 📊 Exposure Value (**EV**) calculation
* ⚡ Real-time light measurement updates
* 📱 Simple and minimal UI designed for photographers

---

## 🧠 How It Works

The application reads **lux values** from the device’s ambient light sensor and converts them into **Exposure Value (EV)**.

Using the exposure triangle formula:

EV = log2(N² / t)

Where:

* **N** = Aperture (f-stop)
* **t** = Shutter speed
* **ISO** adjusts sensitivity

This allows the app to estimate proper exposure settings based on measured light.

---

## 🛠 Built With

* **Flutter**
* **Dart**
* Android **Ambient Light Sensor API**

---

## 📂 Project Structure

```
lib/
 ├── main.dart
 ├── screens/
 ├── widgets/
 ├── services/
```

---

## 🚀 Getting Started

### 1️⃣ Clone the repository

```
git clone https://github.com/Aristyo2006/LELEMETER.git
```

### 2️⃣ Go to project folder

```
cd LELEMETER
```

### 3️⃣ Install dependencies

```
flutter pub get
```

### 4️⃣ Run the app

```
flutter run
```

---

## 📱 Requirements

* Android device with **Ambient Light Sensor**
* Flutter SDK installed

---

## 🎯 Future Improvements

* Histogram
* False Color exposure
* Cine mode (180° shutter rule)
* ND filter compensation
* Exposure lock
* Better UI for the exposure triangle


---

## 📜 License

This project is open source and available under the **MIT License**.
