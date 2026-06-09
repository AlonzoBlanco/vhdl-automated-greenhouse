# FPGA Smart Roof Controller

A fully automated, weather-responsive retractable roof system designed in **VHDL** and deployed on an **Intel MAX 10 DE10-Lite FPGA**. 

This project processes real-time environmental data using digital sensors and an internal Analog-to-Digital Converter (ADC) to control a DC motor via an H-Bridge. It evaluates rain, light intensity, and soil moisture levels through a custom Finite State Machine (FSM) to protect crops or indoor spaces while optimizing natural irrigation and ventilation.

## Features
* **Sensor Integration:** Interfaces with analog soil moisture sensors, digital rain sensors, and photoresistors (LDR).
* **Hardware ADC:** Utilizes the Intel MAX 10 Internal Modular ADC (via IP Catalog) to process analog voltage from the capacitive soil sensor into a mapped 0-100% moisture reading.
* **Robust FSM Control:** A deterministic Finite State Machine handles motor timing and logical conditions to prevent mechanical stress.
* **Seven-Segment UI:** Real-time visualization of the soil moisture percentage directly on the FPGA's 7-segment displays.

## Hardware Requirements
* **FPGA Board:** Terasic DE10-Lite (Intel MAX 10 `10M50DAF484C7G`).
* **Sensors:**
  * Capacitive Soil Moisture Sensor v1.2 (Analog: `SEN-HS-CAP`).
  * Rain Sensor with LM393 Comparator (Digital: `FC-37`).
  * Light Dependent Resistor Module (Digital: `LDR`).
* **Actuator:** DC Motor controlled by a `DRV8833` (or `L298N`) H-Bridge Motor Driver.
* **Power:** External 5V supply for the motor (with common ground to the FPGA).

## System Architecture

The project follows a hierarchical structural design in VHDL:

1. **`sistema_techo_top.vhd` (Top-Level):** The physical framework routing external pins to internal signals. Instantiates the ADC IP core and connects the analog/digital domains.
2. **`techo_retratil_fsm.vhd` (The Brain):** The FSM that evaluates concurrent rules to drive the H-Bridge and output BCD data to the displays.
3. **Peripheral Modules:** Filter blocks and logic level normalizers (`entrada_digital_de10_lite.vhd`, `sen_hs_cap_de10.vhd`) to ensure clean signals and prevent debouncing issues.

### Decision Logic (Truth Table)
The system operates under a conservative safety protocol prioritizing extreme weather protection:

| Condition | Rain | Sun (LDR) | Soil Moisture | Action |
| :--- | :---: | :---: | :---: | :--- |
| **Flood Protection** | Yes | Any | $\ge$ 70% | **CLOSE** Roof |
| **Natural Irrigation**| Yes | No | < 70% | **OPEN** Roof |
| **Sun Protection** | No | Yes | Any | **CLOSE** Roof |
| **Ventilation** | No | No | < 70% | **OPEN** Roof |
| **Rest (Ideal)** | No | No | $\ge$ 70% | **STANDBY** |

*Note: Any adverse weather combination immediately triggers the closing sequence.*

## Pin Mapping (Arduino Header)
| Peripheral | Pin / Port | Function |
| :--- | :--- | :--- |
| **SEN-HS-CAP** | `A0` | Analog input for raw moisture voltage |
| **FC-37** | `IO0` | Active-low digital rain detection |
| **LDR** | `IO1` | Active-low digital extreme light detection |
| **DRV8833 IN1** | `IO2` | Motor direction 1 (Forward/Open) |
| **DRV8833 IN2** | `IO3` | Motor direction 2 (Reverse/Close) |
| **DRV8833 EN** | `IO4` | PWM / Motor Enable |

## Setup and Compilation
1. Clone this repository and open the `.qpf` file in **Quartus Prime Lite Edition**.
2. If the internal ADC IP core throws a library error (`10481`), open *Platform Designer*, generate the HDL for `adc_interno.qsys` targeting the **DE10-Lite** board, and ensure the `.qip` file is linked in the project files.
3. Verify the pin assignments using the Pin Planner or the provided `.qsf` file.
4. Compile the design and program the FPGA via the Quartus Programmer using the USB-Blaster interface.

## Author
**Gabriel Alonzo Blanco Pulido** *Computer Engineering Student at Universidad Nacional Autónoma de México (UNAM)*
