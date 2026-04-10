# 🚀 FPGA Edge Vision & AI Accelerator Portfolio

> **Zynq SoC 기반의 [비전 정렬 제어] 및 [순수 RTL CNN 가속기] 개발 프로젝트**

본 저장소(Repository)는 FPGA의 하드웨어 가속 및 임베디드 제어 역량을 증명하기 위해 진행된 **두 개의 독립적인 프로젝트**를 포함하고 있습니다. 
첫 번째 프로젝트는 픽셀 밀도 기반의 **모터 자동 정렬 시스템**이며, 두 번째 프로젝트는 상용 IP 없이 밑바닥부터 설계한 **CNN 하드웨어 가속기**입니다.

---

## 📁 Project 1: Vision Auto-Alignment System (StageMov)
**카메라 영상의 픽셀 밀도를 분석하여 객체의 중심을 찾고, 모터를 통해 목표 좌표로 자동 정렬하는 시스템**

### 1. System Architecture
* **하드웨어 가속 연산:** OV7670 카메라 영상을 Zero-Latency로 수신하고, 특정 색상 픽셀의 밀도와 분포를 누적 연산하여 객체의 무게중심(Center of Gravity) 좌표를 실시간으로 산출합니다.
* **PS-PL Co-design (AXI4-Lite):** 산출된 좌표를 Custom AXI IP를 통해 프로세서(PS)로 전달하고, PS에서 계산된 오차를 바탕으로 스테퍼 모터 IP를 제어합니다.
* **FSM Motor Control:** L298N 드라이버 제어를 위한 8-State 유한상태기계(FSM)를 설계하여 NEMA17 모터를 Half-Step으로 정밀 제어합니다.

### 2. Troubleshooting: Y-Axis Drift Issue
* **문제:** 카메라 프레임 하단(Y좌표 478 이후)에 발생하는 화이트 노이즈가 유효 픽셀 밀도로 인식되어, 중심 좌표가 실제 물체보다 아래로 쏠리는 현상 발생.
* **해결:** `RGB.vhd` 및 캡처 로직 내에 Y 카운터 값을 검사하는 **하드웨어 마스킹 로직**을 추가하여, 478라인 이후의 픽셀 데이터 연산을 강제로 차단함으로써 좌표의 정확도를 99% 이상으로 끌어올림.

---

## 📁 Project 2: RTL-based CNN Hardware Accelerator
**상용 AI IP나 HLS를 사용하지 않고, 디지털 논리회로(Pure Verilog) 레벨에서 직접 설계한 CNN 추론 가속기**

### 1. System Architecture
* **Line Buffering (`line3_buffer.v`):** 외부 메모리 병목을 없애기 위해 내부 BRAM을 추론하여, 스트리밍 영상의 딱 3줄만 저장하는 공간 최적화 기법 적용.
* **3x3 Sliding Window (`window_gen_3x3.v`):** 라인 버퍼의 데이터를 Shift Register로 받아 클럭마다 3x3 Receptive Field를 동적으로 생성.
* **Parallel MAC Engine (`conv_calc.v`):** 9개의 곱셈기와 누산기를 병렬 배치하여 1 클럭당 1개의 합성곱 연산을 도출하며, Pipeline Register를 삽입하여 동작 주파수(Fmax) 극대화.
* **Fused Activation & Pooling:** 연산 결과의 부호 비트로 실시간 ReLU를 수행하고, 2x2 영역의 최댓값(Max Pooling)을 지연 없이 추출하여 객체(원, 사각형, 삼각형)의 형태를 추론.

### 2. Troubleshooting: Timing Violation in Inference
* **문제:** 169개의 픽셀을 순차적으로 MAC 연산할 경우, 프레임 레이트를 따라가지 못해 실시간 추론에 병목 발생.
* **해결:** `fc_layer.v`에서 입력 데이터를 4개의 병렬 채널로 나누고 가중치 배열을 분할하는 **4-Channel 병렬 MAC 아키텍처**로 전면 재설계하여 연산 소요 클럭을 1/4로 획기적으로 단축.

---
