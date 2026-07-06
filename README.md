Salari Position Manager

# Salari Position Manager 🎯
===

# 

# \*\*Version 4.70\*\* — An interactive Position Manager Expert Advisor (EA) for \*\*MetaTrader 5 (MQL5)\*\*.

# 

# \---

# 

# \## 📋 Overview

# 

# Salari Position Manager provides a fully interactive panel on your MT5 chart to:

# 

# \- \*\*Create visual trade setups\*\* (BUY/SELL) with Entry, SL, and TP lines directly on the chart

# \- \*\*Visual zones\*\* showing profit and loss areas projected forward

# \- \*\*Group drag\*\* — drag the Entry line to move SL and TP together

# \- \*\*Risk/Reward (RR) calculator\*\* — adjust TP based on RR ratio

# \- \*\*Apply SL/TP\*\* to existing positions

# \- \*\*Break Even (BE)\*\* — move SL to break-even manually or automatically

# \- \*\*Trailing Stop\*\* — automatic trailing of SL as price moves

# \- \*\*Partial Close\*\* — close a percentage of position volume

# \- \*\*Close buttons\*\* — close Buy positions, Sell positions, or all at once

# \- \*\*4 Color Themes\*\* — Custom, TradingView, Blue/Orange, Purple/Aqua, Mono Gray

# \- \*\*Draggable panel\*\* — move the panel anywhere on the chart

# \- \*\*Minimizable\*\* — collapse panel to save space

# 

# \---

# 

# \## 🚀 Installation

# 

# 1\. Copy `Salari\_Position\_Manager.mq5` to your MT5 `Experts` folder:

# &#x20;  ```

# &#x20;  %AppData%\\MetaQuotes\\Terminal\\TerminalID\\MQL5\\Experts\\

# &#x20;  ```

# 2\. Restart MetaTrader 5 or refresh the Navigator panel.

# 3\. Drag \& drop the EA onto any chart.

# 4\. Configure inputs as needed (see below).

# 

# \---

# 

# \## ⚙️ Input Parameters

# 

# | Parameter | Default | Description |

# |-----------|---------|-------------|

# | `InpOnlyCurrentSymbol` | `true` | Manage only the current chart symbol |

# | `InpMagicFilter` | `-1` | Filter by magic number (-1 = all) |

# | `InpOrderMagic` | `5555` | Magic number for orders placed via buttons |

# | `InpOrderComment` | `"PM Interactive"` | Comment for button-based orders |

# | `InpDeviationPoints` | `20` | Max slippage in points |

# | `InpDefaultOrderVolume` | `0.10` | Default lot size |

# | `InpDefaultSLPoints` | `300` | Default SL distance (points) |

# | `InpDefaultTPPoints` | `600` | Default TP distance (points) |

# | `InpDefaultBETrigger` | `200` | Auto break-even trigger distance |

# | `InpDefaultBELock` | `20` | Break-even lock-in distance |

# | `InpDefaultTrailPoints` | `250` | Default trailing stop distance |

# | `InpDefaultPartialPct` | `50.0` | Default partial close percentage |

# | `InpTrailStepPoints` | `20` | Minimum SL improvement step for trailing |

# | `InpSetupProjectionBars` | `28` | Width of projection zone in bars |

# 

# \---

# 

# \## 🎨 How to Use

# 

# 1\. \*\*Create a Setup:\*\* Click \*\*BUY SETUP\*\* or \*\*SELL SETUP\*\* — yellow dashed Entry line, red SL, green TP appear on the chart.

# 2\. \*\*Adjust:\*\* Drag lines directly on the chart OR use the panel's SL/TP/RR +/- buttons and edit fields.

# 3\. \*\*Group Drag:\*\* Click and drag the Entry line — SL and TP move together.

# 4\. \*\*Place Order:\*\* Set your lot size and click \*\*Place Order\*\* — supports Market, Limit, and Stop orders.

# 5\. \*\*Manage Positions:\*\* Select positions and click \*\*SL/TP\*\*, \*\*BreakEven\*\*, \*\*Trailing\*\*, \*\*Partial\*\*, or \*\*Close\*\* buttons.

# 

# \---

# 

# \## 🧩 Technical Details

# 

# \- Written in \*\*MQL5\*\* for MetaTrader 5

# \- Uses `CTrade` for trade operations

# \- Event-driven UI via `OnChartEvent`

# \- Auto BE and Trailing run on `OnTick()`

# \- Persistent panel position via `GlobalVariable`

# \- All chart objects prefixed with `PM\_`

# 

# \---

# 

# \## 📝 License

# 

# This project is provided for educational and trading purposes. Use at your own risk.

# 

# \---

# 

# \## 🔗 Links

# 

# \- \[MetaTrader 5](https://www.metatrader5.com/)

# \- \[MQL5 Documentation](https://www.mql5.com/en/docs)

