# Pro Trading Panel 🎯

**Version 3.10** — An interactive Professional Trading Panel Expert Advisor (EA) for **MetaTrader 5 (MQL5)** with TradingView-style visual setup.

---

## 📋 Overview

Pro Trading Panel provides a fully interactive panel on your MT5 chart to:

- **Create visual trade setups** (BUY/SELL) with Entry, SL, and TP lines directly on the chart
- **Visual zones** showing profit and loss areas projected forward
- **Group drag** — drag the Entry line to move SL and TP together
- **Risk/Reward (RR) calculator** — auto-calculated on chart
- **Real-time P&L in account currency** next to SL/TP lines
- **Buy Zone / Sell Zone** — unlimited draggable colored zones
- **Apply SL/TP** to existing positions
- **Break Even (BE)** — move SL to break-even manually or automatically
- **Trailing Stop** — automatic trailing of SL as price moves
- **Partial Close** — close a percentage of position volume
- **Close buttons** — close Buy positions, Sell positions, or all at once
- **Confirmed History** — setup boxes remain on chart after confirmation, even after timeframe changes
- **Manual SL/TP editing** — click and type values directly
- **Draggable panel** — move the panel anywhere on the chart
- **Minimizable** — collapse panel to save space
- **3D Raised buttons** — modern flat-ui with raised borders

---

## 🚀 Installation

1. Copy `Professional_Trading_Panel.mq5` to your MT5 `Experts` folder:
   ```
   %AppData%\MetaQuotes\Terminal\TerminalID\MQL5\Experts\
   ```
2. Restart MetaTrader 5 or refresh the Navigator panel.
3. Drag & drop the EA onto any chart.
4. Configure inputs as needed (see below).

---

## ⚙️ Input Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DefaultLot` | `0.10` | Default lot size |
| `LotStep` | `0.01` | Lot increment step |
| `DefaultTP` | `300` | Default Take Profit (points) |
| `DefaultSL` | `150` | Default Stop Loss (points) |
| `UseTrailing` | `false` | Enable trailing stop on startup |
| `TrailingStop` | `30` | Default trailing stop distance |
| `BreakEvenPips` | `20` | Default break-even trigger distance |

---

## 🎨 How to Use

### Basic Trading:
1. **Create a Setup:** Click **BUY ▲** or **SELL ▼** — Entry (dashed), SL, TP lines appear
2. **Adjust:** Drag lines directly on chart OR use panel's +/- buttons
3. **Group Drag:** Click & drag Entry line — SL and TP move together
4. **Place Order:** Click **✅ Confirm** — supports Market, Limit, and Stop orders
5. **Cancel:** Click **❌ Cancel** to remove active setup (confirmed setups stay)

### Zones:
1. Click **Buy Zone** or **Sell Zone** — colored rectangle appears on chart center
2. Drag it anywhere on chart
3. Click again for unlimited zones

### Position Management:
- Click **Trailing Stop** to enable/disable auto-trailing
- Click **Break Even** to enable/disable auto break-even
- Use **SL/TP** buttons to apply SL/TP to existing positions
- **Close Buy**, **Close Sell**, **Close Profit**, **PANIC CLOSE ALL**

### Manual Editing:
- Click directly on SL/TP numeric fields in panel
- Type desired value and press **Enter**

---

## 🧩 Panel Layout

```
┌─────────────────────┐
│  PRO TRADING PANEL  │
├─────────────────────┤
│  BUY ▲    SELL ▼    │
│ Buy Zone  Sell Zone │
│ ✅ Confirm ❌ Cancel │
│  VOLUME LOT:[0.10]  │
│   SL        TP      │
│ [−][150][+] [−][300] │
│[Trail Stop][BreakEv]│
│[−] 30 [+]  [−]20 [+]│
│─────────────────────│
│ Buy: 1 (0.10 Lot)   │
│ Sell: 0 (0.00 Lot)  │
│ Total Profit: $0.00 │
│ CloseBuy CloseSell  │
│ CloseProfit         │
│ [ PANIC CLOSE ALL ] │
└─────────────────────┘
```

---

## 🧩 Technical Details

- Written in **MQL5** for MetaTrader 5
- Uses `CTrade` for trade operations
- Event-driven UI via `OnChartEvent`
- Auto BE and Trailing run on `OnTimer()`
- Persistent panel position and setups via `GlobalVariable`
- Confirmed setups survive timeframe changes
- All chart objects prefixed with `ProPanel_`

---

## 📝 License

This project is provided for educational and trading purposes. Use at your own risk.

---

## 🔗 Links

- [MetaTrader 5](https://www.metatrader5.com/)
- [MQL5 Documentation](https://www.mql5.com/en/docs)
