# Wgtech Starter Kit


## Overview

This document describes the application and is intended to help users understand and use the system effectively.

The application consists of four main pages:


## Live View Page

This is the default page. It is used to specify the type of input video stream for model inferencing and predictions.

On this page, input for the video stream is provided. There are three types of inputs available:

### 1) RTSP

Provide RTSP links of cameras within the same network. Using Ethernet is recommended for better stream stability.

**Steps:**
Enter RTSP link → Connect → Start Stream

![RTSP](Images/rtsp.png)

Once an RTSP stream is entered, it is saved under **Saved Streams** for easier future access.

---

### 2) USB

If USB cameras are connected to the Raspberry Pi 5 USB ports, they can be accessed here.

**Steps:**
Select a camera (from the dropdown list) → Start Stream

![USB](Images/usb.png)

If the USB camera is not visible in the application, use the refresh icon to reload available devices.

---

### 3) Video File

If `.mp4` files are present in the local storage of your computer, browse and input them here. 

**Steps:**
Choose File → Use Video File → Start Stream

![Video File](Images/video_file.png)

When the **Use Video File** button is clicked, a notification appears confirming the selected file (e.g., Ocean.mp4).

---

## Recordings Page

This page is used to save recordings. There's a default path mentioned, where it's get saved to. Here, it's the standard path.

**Steps:**
Select Slot → Start Recording → Pause or Stop Recording

![Recording](Images/recording.png)

**Important:** Recording duration should be a minimum of 15 seconds.

---

## Playback Page

This page is used to view recorded videos that were recorded in the Recordings page.

Select a recording from the list, and the video will be displayed on the right-hand side.

![Playback](Images/playback.png)

---

## Models Page

This page is used to manage models for inferencing.

The application includes a default model, YOLOv8 (You Only Look Once), pretrained on the COCO dataset, along with that, you can insert your own custom models. Currently any Custom trained YOLO models with dataset can be uploaded.

![Model](Images/model.png)

---

### Add Model

Click **Add Model**, then select the model type: Default Model or Custom Model.

![Add Model](Images/addmodel.png)

---

### Default Model

**Fields required:**

* Model Name
* Cores
* COCO Class IDs
* Description

![Default Model](Images/default.png)

---

### Custom Model

**Fields required:**

* Model Name
* Cores
* Dataset Name
* Description
* Model Weights
* Calibration Dataset

![Custom Model](Images/custom.png)

---

### Deployment

Click **Deploy** to start the deployment process.

![Deployment](Images/deployment.png)

After clicking deploy, the model appears under **Active Models** while deployment is in progress (typically 20–60 minutes).

To remove a model, use the remove option from any slot and confirm the action.

---

## Getting Started

The system is now ready to be used.

Refer to the main README for setup and installation instructions. Once the application is running, this guide can be used to navigate and operate the system effectively.

---

## ❓ FAQs

### 1. Why is my RTSP stream not working?

Ensure that:

* The camera is on the same network
* The RTSP link is correct
* A stable Ethernet connection is used, if possible

---

