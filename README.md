# AVR Rock-Paper-Scissors Game

A two-player Rock-Paper-Scissors game implemented in AVR assembly language for the ATmega32U4 microcontroller, featuring LCD display output and USART communication between two boards.

## Authors
- Thomas Landzaat
- Alexander Reed

**Date:** December 4, 2024

## Hardware Requirements

- **Microcontroller:** ATmega32U4
- **Display:** LCD with backlight support
- **Communication:** USART1 at 2400 bps
- **Input:** Two push buttons connected to INT0 (PD2) and INT1 (PD3)
- **Status Button:** PD7 for ready signal
- **LEDs:** Port B (PB4-PB7) for countdown display

## Features

### Game Flow
1. **Welcome Screen:** Displays "Welcome!" and prompts to press PD7
2. **Ready State:** Players press PD7 to signal readiness
3. **Synchronization:** Boards communicate via USART to ensure both players are ready
4. **Countdown:** Visual LED countdown (4-3-2-1) with 1.5-second intervals
5. **Hand Selection:** Players choose Rock, Paper, or Scissors using buttons
6. **Result Display:** Shows both players' choices and declares winner

### Communication Protocol
- **Baud Rate:** 2400 bps
- **Frame Format:** 8 data bits, 2 stop bits
- **Ready Signal:** `0b11111111` exchanged between boards
- **Hand Data:** Encoded player choices transmitted after selection

### Game Logic
- **Rock (0)** beats Scissors (2)
- **Paper (1)** beats Rock (0) 
- **Scissors (2)** beats Paper (1)
- Identical choices result in a tie

## Code Structure

### Main Components

#### Initialization (`INIT`)
- Stack pointer configuration
- Port setup (Port B output, Port D input with pull-ups)
- LCD initialization and backlight activation
- USART1 configuration
- Timer/Counter1 setup for delays
- External interrupt configuration

#### Game States
- **`DISPLAY_HOLD`:** Welcome screen display
- **`DISPLAY_READY`:** Ready state with opponent waiting message
- **`LED_COUNTDOWN`:** Visual countdown with LED sequence
- **`DISPLAYWINNER`:** Final result showing both choices and outcome

#### Communication Functions
- **`TRANSMIT_READY`:** Sends ready signal via USART
- **`USART_RECEIVE`:** Handles incoming USART data
- **`TRANSMIT_HAND`:** Sends player's choice to opponent
- **`OPP`:** Processes opponent's hand data and displays choices

#### Input Handling
- **`BUTTON` (INT0):** Cycles through Rock → Paper → Scissors for Player 1
- **`BUTTON2` (INT1):** Cycles through Rock → Paper → Scissors for Player 2
- Button debouncing with wait loops

#### Timing Functions
- **`WAIT_1_5sec`:** Precise 1.5-second delay using Timer1
- **`Wait`:** General-purpose delay function (~10ms per count)

## Memory Organization

### Register Definitions
```assembly
.def    mpr = r16        ; Multi-Purpose Register
.def    i = r17          ; Loop counter
.def    reg16 = r18      ; Constant value (0x04)
.def    ctr1 = r19       ; Player 2 choice counter
.def    ctr = r23        ; Player 1 choice counter
.def    STRING_DISPLAY = r24  ; Display helper
.def    waitcnt = r25    ; Wait loop counter
```

### String Data
Game strings stored in program memory:
- Welcome messages
- Hand options (Rock, Paper, Scissors)
- Result messages (Win, Lose, Tie)
- Status indicators

## Technical Details

### Interrupt Vectors
- **Reset:** `$0000` → `INIT`
- **INT0:** `$0002` → `BUTTON` (Player 1 input)
- **INT1:** `$0004` → `BUTTON2` (Player 2 input)
- **USART RX:** `$0032` → `USART_Receive`

### Timer Configuration
- **Timer1:** Normal mode with 1024 prescaler
- **Overflow Value:** `0xFFB1` for precise 10ms timing
- **Usage:** LED countdown delays and button debouncing

### USART Settings
- **Baud Rate:** 2400 bps (UBRR1L = 0xCF)
- **Control:** Receiver and transmitter enabled
- **Data Format:** 8N2 (8 data, no parity, 2 stop bits)

## Usage Instructions

1. **Setup:** Connect two boards with USART communication
2. **Start:** Power on both systems - welcome screen appears
3. **Ready:** Press PD7 on both boards to signal readiness
4. **Wait:** System waits for opponent confirmation
5. **Countdown:** Watch LED countdown (4 seconds)
6. **Play:** Use INT0/INT1 buttons to select your hand during countdown
7. **Results:** View both players' choices and game outcome
8. **Repeat:** System automatically returns to start for next round

## File Dependencies

- `m32U4def.inc` - ATmega32U4 definitions
- `LCDDriver.asm` - LCD control functions

## Building and Programming

This code is designed for the AVR assembler and requires:
1. AVR toolchain (avr-gcc, avr-as)
2. Programming hardware (AVR ISP, etc.)
3. Proper fuse bit configuration for ATmega32U4

## License

This project is provided as-is for educational purposes.

---

*For questions or issues, please contact the authors.*
