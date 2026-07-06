// Salari Position Manager v4.70 

#property strict
#property version   "4.70"
#property description "[Arena.ai](http://Arena.ai) - Salari Position Manager"
#property description "Group-drag Entry moves SL/TP together, zones persist after price passes, manual clear."

#include <Trade/Trade.mqh>

CTrade trade;

input bool             InpOnlyCurrentSymbol   = true;               // Manage only current chart symbol
input long             InpMagicFilter         = -1;                 // -1 = all magic numbers for management actions
input long             InpOrderMagic          = 5555;               // Magic number for Buy/Sell buttons
input string           InpOrderComment        = "PM Interactive";  // Comment for button-based orders
input ulong            InpDeviationPoints     = 20;                 // Max slippage in points
input double           InpDefaultOrderVolume  = 0.10;               // Default order volume for Buy/Sell setup
input int              InpDefaultSLPoints     = 300;                // Default SL distance (points)
input int              InpDefaultTPPoints     = 600;                // Default TP distance (points)
input int              InpDefaultBETrigger    = 200;                // Default auto break-even trigger (points)
input int              InpDefaultBELock       = 20;                 // Default break-even lock-in (points)
input int              InpDefaultTrailPoints  = 250;                // Default trailing distance (points)
input double           InpDefaultPartialPct   = 50.0;               // Default partial close percent
input int              InpTrailStepPoints     = 20;                 // Minimum SL improvement step for trailing
input int              InpSetupProjectionBars = 28;                 // Width of setup zone on chart (bars forward)
input ENUM_BASE_CORNER InpPanelCorner         = CORNER_LEFT_UPPER;  // Panel corner
input int              InpPanelX              = 20;                 // Panel X offset
input int              InpPanelY              = 20;                 // Panel Y offset
input color            InpPanelBgColor        = C'30,35,42';       // Panel background
input color            InpPanelBorderColor    = C'55,65,80';       // Panel border
input color            InpPrimaryButtonColor  = C'50,120,180';     // Default button color
input color            InpDangerButtonColor   = C'180,50,50';      // Close button color
input color            InpBuyButtonColor      = C'30,150,100';      // Buy setup button color
input color            InpSellButtonColor     = C'190,60,60';       // Sell setup button color
input color            InpTextColor           = C'230,235,245';    // Text color
input color            InpProfitZoneColor     = C'40,160,90';      // Default profit zone color
input color            InpLossZoneColor       = C'220,60,60';       // Default loss zone color
input color            InpEntryLineColor      = C'255,200,50';      // Default entry line color
input color            InpSLLineColor         = C'220,60,60';       // Default SL line color
input color            InpTPLineColor         = C'40,160,90';       // Default TP line color

const string PREFIX = "PM_";
const string GV_PANEL_X = "SalariPM.PanelX";
const string GV_PANEL_Y = "SalariPM.PanelY";

bool   g_auto_be_enabled  = false;
bool   g_trailing_enabled = false;
bool   g_setup_active     = false;
int    g_setup_direction  = 0;      // 1=BUY, -1=SELL
string g_setup_symbol     = "";
color  g_profit_zone_color = clrPaleGreen;
color  g_loss_zone_color   = clrMistyRose;
color  g_entry_line_color  = clrGold;
color  g_sl_line_color     = clrFireBrick;
color  g_tp_line_color     = clrLimeGreen;
int    g_color_theme_index = 0;
bool   g_panel_minimized   = false;
int    g_panel_x           = 0;
int    g_panel_y           = 0;
bool   g_panel_dragging    = false;
int    g_drag_offset_x     = 0;
int    g_drag_offset_y     = 0;
string g_ui_lot_text       = "";
string g_ui_sl_text        = "";
string g_ui_tp_text        = "";
string g_ui_rr_text        = "";
string g_ui_be_trig_text   = "";
string g_ui_be_lock_text   = "";
string g_ui_trail_text     = "";
string g_ui_partial_text   = "";

// Cached setup prices for group drag
double g_cached_entry = 0.0;
double g_cached_sl    = 0.0;
double g_cached_tp    = 0.0;

enum ENUM_PM_SETUP_DIRECTION
{
   PM_SETUP_NONE = 0,
   PM_SETUP_BUY  = 1,
   PM_SETUP_SELL = -1
};

string ObjName(const string suffix)
{
   return PREFIX + suffix;
}

void DeleteIfExists(const string name)
{
   if(ObjectFind(0, name) != -1)
      ObjectDelete(0, name);
}

void SetSetupInfoText(const string text)
{
   if(ObjectFind(0, ObjName("setup_info")) != -1)
      ObjectSetString(0, ObjName("setup_info"), OBJPROP_TEXT, text);
}

void SetMiniInfoText(const string text)
{
   if(ObjectFind(0, ObjName("mini_info")) != -1)
      ObjectSetString(0, ObjName("mini_info"), OBJPROP_TEXT, text);
}

color DarkerColor(const color c, const double factor=0.78)
{
   uint v = (uint)c;
   int r = (int)((v      ) & 0xFF);
   int g = (int)((v >> 8 ) & 0xFF);
   int b = (int)((v >> 16) & 0xFF);
   r = (int)MathMax(0, MathMin(255, (int)MathRound(r * factor)));
   g = (int)MathMax(0, MathMin(255, (int)MathRound(g * factor)));
   b = (int)MathMax(0, MathMin(255, (int)MathRound(b * factor)));
   return (color)(r | (g << 8) | (b << 16));
}

color LighterColor(const color c, const double factor=1.30)
{
   uint v = (uint)c;
   int r = (int)((v      ) & 0xFF);
   int g = (int)((v >> 8 ) & 0xFF);
   int b = (int)((v >> 16) & 0xFF);
   r = (int)MathMax(0, MathMin(255, (int)MathRound(r * factor)));
   g = (int)MathMax(0, MathMin(255, (int)MathRound(g * factor)));
   b = (int)MathMax(0, MathMin(255, (int)MathRound(b * factor)));
   return (color)(r | (g << 8) | (b << 16));
}

void SetEditTextSafe(const string name, const string text)
{
   if(ObjectFind(0, name) != -1)
      ObjectSetString(0, name, OBJPROP_TEXT, text);
}

bool SetupObjectsPresent()
{
   return (ObjectFind(0, ObjName("setup_entry")) != -1 &&
           ObjectFind(0, ObjName("setup_sl"))    != -1 &&
           ObjectFind(0, ObjName("setup_tp"))    != -1);
}

void RestoreSetupFromObjects()
{
   if(!SetupObjectsPresent())
      return;
   double entry = ObjectGetDouble(0, ObjName("setup_entry"), OBJPROP_PRICE);
   double sl    = ObjectGetDouble(0, ObjName("setup_sl"), OBJPROP_PRICE);
   double tp    = ObjectGetDouble(0, ObjName("setup_tp"), OBJPROP_PRICE);
   if(sl < entry && tp > entry)
      g_setup_direction = PM_SETUP_BUY;
   else if(sl > entry && tp < entry)
      g_setup_direction = PM_SETUP_SELL;
   else
      g_setup_direction = PM_SETUP_NONE;
   g_setup_active = (g_setup_direction != PM_SETUP_NONE);
   g_setup_symbol = _Symbol;
   if(g_setup_active)
   {
      g_cached_entry = entry;
      g_cached_sl    = sl;
      g_cached_tp    = tp;
   }
}

string MoneyTooltipText(const bool is_tp, const double entry, const double level_price)
{
   double volume = GetEditDouble(ObjName("edit_lot"), InpDefaultOrderVolume);
   volume = NormalizeVolumeToStep(_Symbol, volume);
   ENUM_ORDER_TYPE order_type = (g_setup_direction == PM_SETUP_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double money = 0.0;
   bool ok = OrderCalcProfit(order_type, _Symbol, volume, entry, level_price, money);
   if(!ok)
   {
      double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tick_size > 0.0 && tick_value > 0.0)
         money = (MathAbs(level_price - entry) / tick_size) * tick_value * volume;
   }
   string ccy = AccountInfoString(ACCOUNT_CURRENCY);
   if(is_tp)
      return StringFormat("Potential Profit: %.2f %s", MathAbs(money), ccy);
   return StringFormat("Potential Loss: %.2f %s", MathAbs(money), ccy);
}

void SetObjectTooltipSafe(const string name, const string tooltip)
{
   if(ObjectFind(0, name) != -1)
      ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

void SavePanelPosition()
{
   GlobalVariableSet(GV_PANEL_X, g_panel_x);
   GlobalVariableSet(GV_PANEL_Y, g_panel_y);
}

bool LoadPanelPosition()
{
   if(!GlobalVariableCheck(GV_PANEL_X) || !GlobalVariableCheck(GV_PANEL_Y))
      return false;
   g_panel_x = (int)GlobalVariableGet(GV_PANEL_X);
   g_panel_y = (int)GlobalVariableGet(GV_PANEL_Y);
   return true;
}

void RefreshZoneColorsFromButtons()
{
   g_profit_zone_color = InpBuyButtonColor;
   g_loss_zone_color   = InpSellButtonColor;
   g_entry_line_color  = InpEntryLineColor;
   g_sl_line_color     = InpSellButtonColor;
   g_tp_line_color     = InpBuyButtonColor;
}

int VolumeDigitsFromStep(const double step)
{
   int digits = 0;
   double scaled = step;
   while(digits < 8 && MathAbs(scaled - MathRound(scaled)) > 1e-8)
   {
      scaled *= 10.0;
      digits++;
   }
   return digits;
}

double NormalizeVolumeToStep(const string symbol, double volume)
{
   double min_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lot_step <= 0.0)
      lot_step = min_lot;
   if(lot_step <= 0.0)
      return volume;
   volume = MathFloor((volume / lot_step) + 1e-8) * lot_step;
   volume = MathMax(0.0, MathMin(volume, max_lot));
   int digits = VolumeDigitsFromStep(lot_step);
   return NormalizeDouble(volume, digits);
}

bool GetBidAsk(const string symbol, double &bid, double &ask)
{
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return false;
   bid = tick.bid;
   ask = tick.ask;
   return true;
}

ENUM_ORDER_TYPE_FILLING GetFillingType(const string symbol)
{
   long filling   = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   long exec_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   if(exec_mode == SYMBOL_TRADE_EXECUTION_MARKET)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

bool SelectedPositionMatchesFilters()
{
   string symbol = PositionGetString(POSITION_SYMBOL);
   long magic    = PositionGetInteger(POSITION_MAGIC);
   if(InpOnlyCurrentSymbol && symbol != _Symbol)
      return false;
   if(InpMagicFilter >= 0 && magic != InpMagicFilter)
      return false;
   return true;
}

int CollectMatchingTickets(ulong &tickets[])
{
   ArrayResize(tickets, 0);
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(!SelectedPositionMatchesFilters())
         continue;
      int size = ArraySize(tickets);
      ArrayResize(tickets, size + 1);
      tickets[size] = ticket;
   }
   return ArraySize(tickets);
}

bool ModifyPositionByTicket(const ulong ticket, double new_sl, double new_tp)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   string symbol = PositionGetString(POSITION_SYMBOL);
   int digits    = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(new_sl > 0.0)
      new_sl = NormalizeDouble(new_sl, digits);
   if(new_tp > 0.0)
      new_tp = NormalizeDouble(new_tp, digits);
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action   = TRADE_ACTION_SLTP;
   request.symbol   = symbol;
   request.position = ticket;
   request.sl       = new_sl;
   request.tp       = new_tp;
   bool sent = OrderSend(request, result);
   if(!sent)
   {
      PrintFormat("SLTP modify failed. Ticket=%I64u, error=%d", ticket, GetLastError());
      return false;
   }
   if(result.retcode != TRADE_RETCODE_DONE)
   {
      PrintFormat("SLTP modify retcode not successful. Ticket=%I64u, retcode=%d", ticket, result.retcode);
      return false;
   }
   return true;
}

bool ReducePositionVolume(const ulong ticket, double close_volume)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   string symbol            = PositionGetString(POSITION_SYMBOL);
   ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double position_volume   = PositionGetDouble(POSITION_VOLUME);
   double min_lot           = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   close_volume = NormalizeVolumeToStep(symbol, close_volume);
   if(close_volume <= 0.0 || close_volume > position_volume + 1e-8)
      return false;
   double remaining = position_volume - close_volume;
   if(remaining > 1e-8 && remaining < min_lot - 1e-8)
   {
      close_volume = NormalizeVolumeToStep(symbol, position_volume - min_lot);
      if(close_volume <= 0.0)
         close_volume = NormalizeVolumeToStep(symbol, position_volume);
   }
   double bid = 0.0, ask = 0.0;
   if(!GetBidAsk(symbol, bid, ask))
      return false;
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action       = TRADE_ACTION_DEAL;
   request.position     = ticket;
   request.symbol       = symbol;
   request.volume       = close_volume;
   request.magic        = 0;
   request.deviation    = InpDeviationPoints;
   request.type_filling = GetFillingType(symbol);
   request.type_time    = ORDER_TIME_GTC;
   if(ptype == POSITION_TYPE_BUY)
   {
      request.type  = ORDER_TYPE_SELL;
      request.price = bid;
   }
   else
   {
      request.type  = ORDER_TYPE_BUY;
      request.price = ask;
   }
   bool sent = OrderSend(request, result);
   if(!sent)
   {
      PrintFormat("OrderSend close/reduce failed. Ticket=%I64u, error=%d", ticket, GetLastError());
      return false;
   }
   if(result.retcode != TRADE_RETCODE_DONE &&
      result.retcode != TRADE_RETCODE_DONE_PARTIAL &&
      result.retcode != TRADE_RETCODE_PLACED)
   {
      PrintFormat("Close/reduce retcode not successful. Ticket=%I64u, retcode=%d", ticket, result.retcode);
      return false;
   }
   return true;
}

bool ClosePositionFully(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return false;
   double volume = PositionGetDouble(POSITION_VOLUME);
   return ReducePositionVolume(ticket, volume);
}

bool CreateRectangleLabel(const string name, const int x, const int y, const int w, const int h,
                          const color bg, const color border)
{
   if(ObjectFind(0, name) == -1)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, InpPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_panel_x + x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, g_panel_y + y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   return true;
}

bool CreateLabel(const string name, const int x, const int y, const string text,
                 const color clr, const int font_size, const bool bold=false)
{
   if(ObjectFind(0, name) == -1)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return false;
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, InpPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_panel_x + x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, g_panel_y + y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Segoe UI Semibold" : "Segoe UI");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   return true;
}

bool CreateButton(const string name, const int x, const int y, const int w, const int h,
                  const string text, const color bg, const color clr=clrWhite)
{
   if(ObjectFind(0, name) == -1)
   {
      if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
         return false;
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, InpPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_panel_x + x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, g_panel_y + y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   color borderHL = LighterColor(bg, 1.35);
   if(borderHL == bg) borderHL = clrWhite;
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderHL);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   return true;
}

bool CreateEdit(const string name, const int x, const int y, const int w, const int h,
                const string text, const color bg=C'24,24,24')
{
   if(ObjectFind(0, name) == -1)
   {
      if(!ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0))
         return false;
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, InpPanelCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_panel_x + x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, g_panel_y + y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'58,58,58');
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpTextColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_RIGHT);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   return true;
}

bool CreateOrMoveHLine(const string name, const double price, const color clr,
                       const bool selectable, const ENUM_LINE_STYLE style, const int width)
{
   bool exists = (ObjectFind(0, name) != -1);
   bool was_selected = false;
   if(!exists)
   {
      if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
         return false;
   }
   else
   {
      was_selected = (bool)ObjectGetInteger(0, name, OBJPROP_SELECTED);
   }
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, was_selected);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   return true;
}

bool CreateOrMoveRectangle(const string name, const datetime t1, const double p1,
                           const datetime t2, const double p2, const color clr)
{
   if(ObjectFind(0, name) == -1)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2))
         return false;
   }
   ObjectMove(0, name, 0, t1, p1);
   ObjectMove(0, name, 1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   return true;
}

bool CreateOrMovePriceText(const string name, const datetime when, const double price,
                           const string text, const color clr)
{
   if(ObjectFind(0, name) == -1)
   {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, when, price))
         return false;
   }
   ObjectMove(0, name, 0, when, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, "Segoe UI Semibold");
   return true;
}

bool IsSetupObjectName(const string name)
{
   return (name == ObjName("setup_entry") ||
           name == ObjName("setup_sl") ||
           name == ObjName("setup_tp") ||
           name == ObjName("setup_profit") ||
           name == ObjName("setup_loss") ||
           name == ObjName("setup_entry_text") ||
           name == ObjName("setup_sl_text") ||
           name == ObjName("setup_tp_text") ||
           name == ObjName("setup_rr_text"));
}

bool IsPanelButtonName(const string name)
{
   return (StringFind(name, ObjName("btn_")) == 0);
}

void DeletePanelUIObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PREFIX) == 0 && !IsSetupObjectName(name))
         ObjectDelete(0, name);
   }
}

void DeleteAllPMObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

void SavePanelState()
{
   if(ObjectFind(0, ObjName("edit_lot")) != -1)
      g_ui_lot_text = ObjectGetString(0, ObjName("edit_lot"), OBJPROP_TEXT);
   if(ObjectFind(0, ObjName("edit_sl")) != -1)
      g_ui_sl_text = ObjectGetString(0, ObjName("edit_sl"), OBJPROP_TEXT);
   if(ObjectFind(0, ObjName("edit_tp")) != -1)
      g_ui_tp_text = ObjectGetString(0, ObjName("edit_tp"), OBJPROP_TEXT);
   if(ObjectFind(0, ObjName("edit_rr")) != -1)
      g_ui_rr_text = ObjectGetString(0, ObjName("edit_rr"), OBJPROP_TEXT);
   if(ObjectFind(0, ObjName("edit_be_trig")) != -1)
      g_ui_be_trig_text = ObjectGetString(0, ObjName("edit_be_trig"), OBJPROP_TEXT);
   if(ObjectFind(0, ObjName("edit_be_lock")) != -1)
      g_ui_be_lock_text = ObjectGetString(0, ObjName("edit_be_lock"), OBJPROP_TEXT);
   if(ObjectFind(0, ObjName("edit_trail")) != -1)
      g_ui_trail_text = ObjectGetString(0, ObjName("edit_trail"), OBJPROP_TEXT);
   if(ObjectFind(0, ObjName("edit_partial")) != -1)
      g_ui_partial_text = ObjectGetString(0, ObjName("edit_partial"), OBJPROP_TEXT);
}

string UseCachedOrDefault(const string cached, const string fallback)
{
   if(StringLen(cached) > 0)
      return cached;
   return fallback;
}

bool IsEditingObject(const string name)
{
   if(ObjectFind(0, name) == -1)
      return false;
   return (bool)ObjectGetInteger(0, name, OBJPROP_SELECTED);
}

void ApplyRRFromPanelInput()
{
   if(!g_setup_active)
      return;
   if(ObjectFind(0, ObjName("edit_rr")) == -1)
      return;
   if(IsEditingObject(ObjName("edit_rr")))
      return;
   string rr_text = ObjectGetString(0, ObjName("edit_rr"), OBJPROP_TEXT);
   if(StringLen(rr_text) == 0)
      return;
   double rr_value = StringToDouble(rr_text);
   if(rr_value <= 0.0)
      return;
   double entry = 0.0, sl = 0.0, tp = 0.0;
   if(!GetSetupPrices(entry, sl, tp))
      return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;
   double risk_distance = MathAbs(entry - sl);
   if(risk_distance <= point * 0.5)
      return;
   double current_rr = 0.0;
   double current_reward = MathAbs(entry - tp);
   if(risk_distance > 0.0)
      current_rr = current_reward / risk_distance;
   if(MathAbs(current_rr - rr_value) < 0.0001)
      return;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double new_tp = tp;
   if(g_setup_direction == PM_SETUP_BUY)
      new_tp = NormalizeDouble(entry + (risk_distance * rr_value), digits);
   else if(g_setup_direction == PM_SETUP_SELL)
      new_tp = NormalizeDouble(entry - (risk_distance * rr_value), digits);
   else
      return;
   ObjectSetDouble(0, ObjName("setup_tp"), OBJPROP_PRICE, new_tp);
   g_ui_rr_text = DoubleToString(rr_value, 2);
   UpdateSetupVisuals();
}

int GetEditInt(const string name, const int fallback)
{
   string text = ObjectGetString(0, name, OBJPROP_TEXT);
   if(StringLen(text) == 0)
      return fallback;
   return (int)StringToInteger(text);
}

double GetEditDouble(const string name, const double fallback)
{
   string text = ObjectGetString(0, name, OBJPROP_TEXT);
   if(StringLen(text) == 0)
      return fallback;
   return StringToDouble(text);
}

string FilterSymbolText()
{
   return InpOnlyCurrentSymbol ? _Symbol : "ALL SYMBOLS";
}

string FilterMagicText()
{
   if(InpMagicFilter < 0)
      return "ALL";
   return StringFormat("%I64d", InpMagicFilter);
}

string AccountModeText()
{
   long margin_mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return "Hedging";
   if(margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
      return "Netting";
   if(margin_mode == ACCOUNT_MARGIN_MODE_EXCHANGE)
      return "Exchange";
   return "Unknown";
}

string SetupSideText()
{
   if(!g_setup_active)
      return "NONE";
   return (g_setup_direction == PM_SETUP_BUY ? "BUY" : "SELL");
}

string PriceToText(const string symbol, const double price)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return DoubleToString(price, digits);
}

double GetLotStep(const string symbol)
{
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if(step <= 0.0)
      step = 0.01;
   return step;
}

void SetLotEditValue(double volume)
{
   double step = GetLotStep(_Symbol);
   int digits  = VolumeDigitsFromStep(step);
   volume      = NormalizeVolumeToStep(_Symbol, volume);
   if(volume < 0.0)
      volume = 0.0;
   ObjectSetString(0, ObjName("edit_lot"), OBJPROP_TEXT, DoubleToString(volume, digits));
}

void AdjustLotField(const int direction)
{
   double step   = GetLotStep(_Symbol);
   double volume = GetEditDouble(ObjName("edit_lot"), InpDefaultOrderVolume);
   volume += (direction * step);
   if(volume < 0.0)
      volume = 0.0;
   SetLotEditValue(volume);
}

void AdjustSLField(const int direction)
{
   int value = GetEditInt(ObjName("edit_sl"), InpDefaultSLPoints);
   value += (direction * 10);
   if(value < 0)
      value = 0;
   ObjectSetString(0, ObjName("edit_sl"), OBJPROP_TEXT, IntegerToString(value));
   ApplySLTPFromEdits();
}

void AdjustTPField(const int direction)
{
   int value = GetEditInt(ObjName("edit_tp"), InpDefaultTPPoints);
   value += (direction * 10);
   if(value < 0)
      value = 0;
   ObjectSetString(0, ObjName("edit_tp"), OBJPROP_TEXT, IntegerToString(value));
   ApplySLTPFromEdits();
}

void ApplySLTPFromEdits()
{
   if(!g_setup_active)
      return;
   double entry = 0.0, sl = 0.0, tp = 0.0;
   if(!GetSetupPrices(entry, sl, tp))
      return;
   int sl_points = GetEditInt(ObjName("edit_sl"), 0);
   int tp_points = GetEditInt(ObjName("edit_tp"), 0);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double new_sl = sl;
   double new_tp = tp;
   if(g_setup_direction == PM_SETUP_BUY)
   {
      if(sl_points > 0) new_sl = NormalizeDouble(entry - (sl_points * point), digits);
      if(tp_points > 0) new_tp = NormalizeDouble(entry + (tp_points * point), digits);
   }
   else if(g_setup_direction == PM_SETUP_SELL)
   {
      if(sl_points > 0) new_sl = NormalizeDouble(entry + (sl_points * point), digits);
      if(tp_points > 0) new_tp = NormalizeDouble(entry - (tp_points * point), digits);
   }
   if(sl_points > 0) ObjectSetDouble(0, ObjName("setup_sl"), OBJPROP_PRICE, new_sl);
   if(tp_points > 0) ObjectSetDouble(0, ObjName("setup_tp"), OBJPROP_PRICE, new_tp);
   UpdateSetupVisuals();
}

void AdjustRRField(const int direction)
{
   double value = GetEditDouble(ObjName("edit_rr"), 2.0);
   value += (direction * 0.1);
   if(value < 0.1)
      value = 0.1;
   ObjectSetString(0, ObjName("edit_rr"), OBJPROP_TEXT, DoubleToString(value, 2));
   ApplyRRFromPanelInput();
}

void AdjustBETrigField(const int direction)
{
   int value = GetEditInt(ObjName("edit_be_trig"), InpDefaultBETrigger);
   value += (direction * 10);
   if(value < 0)
      value = 0;
   ObjectSetString(0, ObjName("edit_be_trig"), OBJPROP_TEXT, IntegerToString(value));
}

void AdjustBELockField(const int direction)
{
   int value = GetEditInt(ObjName("edit_be_lock"), InpDefaultBELock);
   value += (direction * 5);
   if(value < 0)
      value = 0;
   ObjectSetString(0, ObjName("edit_be_lock"), OBJPROP_TEXT, IntegerToString(value));
}

void AdjustTrailField(const int direction)
{
   int value = GetEditInt(ObjName("edit_trail"), InpDefaultTrailPoints);
   value += (direction * 10);
   if(value < 0)
      value = 0;
   ObjectSetString(0, ObjName("edit_trail"), OBJPROP_TEXT, IntegerToString(value));
}

string ThemeName()
{
   switch(g_color_theme_index)
   {
      case 1:  return "TradingView";
      case 2:  return "Blue/Orange";
      case 3:  return "Purple/Aqua";
      case 4:  return "Mono Gray";
      default: return "Custom";
   }
}

void ApplyColorTheme(const int index)
{
   g_color_theme_index = index;
   switch(index)
   {
      case 1: // TradingView
         g_profit_zone_color = C'40,160,90';
         g_loss_zone_color   = C'220,60,60';
         g_entry_line_color  = C'255,200,50';
         g_sl_line_color     = C'220,60,60';
         g_tp_line_color     = C'40,160,90';
         break;
      case 2: // Blue/Orange
         g_profit_zone_color = C'30,120,220';
         g_loss_zone_color   = C'230,120,30';
         g_entry_line_color  = C'50,180,255';
         g_sl_line_color     = C'230,120,30';
         g_tp_line_color     = C'30,120,220';
         break;
      case 3: // Purple/Aqua
         g_profit_zone_color = C'150,80,220';
         g_loss_zone_color   = C'30,200,200';
         g_entry_line_color  = C'200,120,255';
         g_sl_line_color     = C'30,200,200';
         g_tp_line_color     = C'150,80,220';
         break;
      case 4: // Mono Gray
         g_profit_zone_color = C'160,160,160';
         g_loss_zone_color   = C'80,80,80';
         g_entry_line_color  = C'220,220,220';
         g_sl_line_color     = C'80,80,80';
         g_tp_line_color     = C'160,160,160';
         break;
      default:
         g_color_theme_index = 0;
         g_profit_zone_color = InpProfitZoneColor;
         g_loss_zone_color   = InpLossZoneColor;
         g_entry_line_color  = InpEntryLineColor;
         g_sl_line_color     = InpSLLineColor;
         g_tp_line_color     = InpTPLineColor;
         break;
   }
}

void CycleTheme(const int delta)
{
   int idx = g_color_theme_index + delta;
   if(idx < 0)
      idx = 4;
   if(idx > 4)
      idx = 0;
   ApplyColorTheme(idx);
   if(!g_setup_active)
      SetSetupInfoText(StringFormat("Theme: %s", ThemeName()));
   if(g_setup_active)
      UpdateSetupVisuals();
}

string DetectSetupOrderModeText(const double entry)
{
   double bid = 0.0, ask = 0.0;
   if(!GetBidAsk(_Symbol, bid, ask))
      return "N/A";
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.00001;
   double tolerance = point * 2.0;
   if(g_setup_direction == PM_SETUP_BUY)
   {
      if(entry < ask - tolerance)
         return "BUY LIMIT";
      if(entry > ask + tolerance)
         return "BUY STOP";
      return "BUY MARKET";
   }
   else if(g_setup_direction == PM_SETUP_SELL)
   {
      if(entry > bid + tolerance)
         return "SELL LIMIT";
      if(entry < bid - tolerance)
         return "SELL STOP";
      return "SELL MARKET";
   }
   return "NONE";
}

string CurrentSetupOrderModeText()
{
   if(!g_setup_active)
      return "NONE";
   double entry = 0.0, sl = 0.0, tp = 0.0;
   if(!GetSetupPrices(entry, sl, tp))
      return "NONE";
   return DetectSetupOrderModeText(entry);
}

void UpdateToggleButtons()
{
   if(ObjectFind(0, ObjName("btn_auto_be")) != -1)
   {
      ObjectSetString(0, ObjName("btn_auto_be"), OBJPROP_TEXT,
                      g_auto_be_enabled ? "Auto BE: ON" : "Auto BE: OFF");
      ObjectSetInteger(0, ObjName("btn_auto_be"), OBJPROP_BGCOLOR,
                       g_auto_be_enabled ? C'30,140,70' : C'70,70,70');
   }
   if(ObjectFind(0, ObjName("btn_trail")) != -1)
   {
      ObjectSetString(0, ObjName("btn_trail"), OBJPROP_TEXT,
                      g_trailing_enabled ? "Trailing: ON" : "Trailing: OFF");
      ObjectSetInteger(0, ObjName("btn_trail"), OBJPROP_BGCOLOR,
                       g_trailing_enabled ? C'30,140,70' : C'70,70,70');
   }
}

bool GetSetupPrices(double &entry, double &sl, double &tp)
{
   if(!g_setup_active)
      return false;
   if(ObjectFind(0, ObjName("setup_entry")) == -1)
      return false;
   if(ObjectFind(0, ObjName("setup_sl")) == -1)
      return false;
   if(ObjectFind(0, ObjName("setup_tp")) == -1)
      return false;
   entry = ObjectGetDouble(0, ObjName("setup_entry"), OBJPROP_PRICE);
   sl    = ObjectGetDouble(0, ObjName("setup_sl"), OBJPROP_PRICE);
   tp    = ObjectGetDouble(0, ObjName("setup_tp"), OBJPROP_PRICE);
   return true;
}

bool ValidateSetup(const double entry, const double sl, const double tp, string &message)
{
   message = "";
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long   stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_stop_distance = stop_level * point;
   if(g_setup_direction == PM_SETUP_BUY)
   {
      if(sl >= entry)
      {
         message = "BUY setup invalid: SL must be below Entry.";
         return false;
      }
      if(tp <= entry)
      {
         message = "BUY setup invalid: TP must be above Entry.";
         return false;
      }
      if(stop_level > 0 && ((entry - sl) < min_stop_distance || (tp - entry) < min_stop_distance))
      {
         message = "BUY setup invalid: SL/TP too close to price.";
         return false;
      }
   }
   else if(g_setup_direction == PM_SETUP_SELL)
   {
      if(sl <= entry)
      {
         message = "SELL setup invalid: SL must be above Entry.";
         return false;
      }
      if(tp >= entry)
      {
         message = "SELL setup invalid: TP must be below Entry.";
         return false;
      }
      if(stop_level > 0 && ((sl - entry) < min_stop_distance || (entry - tp) < min_stop_distance))
      {
         message = "SELL setup invalid: SL/TP too close to price.";
         return false;
      }
   }
   else
   {
      message = "No active setup.";
      return false;
   }
   return true;
}

bool ValidateOrderVolume(double &volume, string &message)
{
   message = "";
   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   volume = NormalizeVolumeToStep(_Symbol, volume);
   if(volume < min_lot - 1e-8)
   {
      message = StringFormat("Volume too small. Min lot = %g", min_lot);
      return false;
   }
   if(volume > max_lot + 1e-8)
   {
      message = StringFormat("Volume too large. Max lot = %g", max_lot);
      return false;
   }
   if(lot_step > 0.0 && MathAbs(MathRound(volume / lot_step) * lot_step - volume) > 1e-8)
   {
      message = "Volume is not aligned with broker lot step.";
      return false;
   }
   return true;
}

void DeleteSetupObjects()
{
   DeleteIfExists(ObjName("setup_entry"));
   DeleteIfExists(ObjName("setup_sl"));
   DeleteIfExists(ObjName("setup_tp"));
   DeleteIfExists(ObjName("setup_profit"));
   DeleteIfExists(ObjName("setup_loss"));
   DeleteIfExists(ObjName("setup_entry_text"));
   DeleteIfExists(ObjName("setup_sl_text"));
   DeleteIfExists(ObjName("setup_tp_text"));
   DeleteIfExists(ObjName("setup_rr_text"));
}

void ResetSetup()
{
   g_setup_active    = false;
   g_setup_direction = PM_SETUP_NONE;
   g_setup_symbol    = "";
   g_cached_entry    = 0.0;
   g_cached_sl       = 0.0;
   g_cached_tp       = 0.0;
   DeleteSetupObjects();
   SetSetupInfoText(StringFormat("Setup: none | Theme: %s", ThemeName()));
   ChartRedraw();
}

color ZoneFillColor(const color base)
{
   return base;
}

int PanelWidthNormal() { return 370; }
int PanelHeightNormal() { return 296; }
int PanelWidthMinimized() { return 220; }
int PanelHeightMinimized() { return 42; }

void LeftCenterPanelOnChart()
{
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   g_panel_x = 18;
   g_panel_y = MathMax(0, (chart_h - PanelHeightNormal()) / 2);
}

void MovePanelTo(const int new_x, const int new_y)
{
   g_panel_x = MathMax(0, new_x);
   g_panel_y = MathMax(0, new_y);
   SavePanelPosition();
   CreatePanel();
}

bool PointInRectPx(const int x, const int y, const int left, const int top, const int width, const int height)
{
   return (x >= left && x <= (left + width) && y >= top && y <= (top + height));
}

bool CanStartPanelDrag(const int mouse_x, const int mouse_y)
{
   if(g_panel_minimized)
   {
      if(!PointInRectPx(mouse_x, mouse_y, g_panel_x, g_panel_y, PanelWidthMinimized(), PanelHeightMinimized()))
         return false;
      if(PointInRectPx(mouse_x, mouse_y, g_panel_x + 190, g_panel_y + 9, 20, 20))
         return false;
      return true;
   }
   // Normal mode: only dragbar area (first 34 px height)
   if(!PointInRectPx(mouse_x, mouse_y, g_panel_x, g_panel_y, PanelWidthNormal(), 34))
      return false;
   // Exclude control buttons in title bar
   if(PointInRectPx(mouse_x, mouse_y, g_panel_x + 252, g_panel_y + 7, 22, 22))
      return false; // theme prev
   if(PointInRectPx(mouse_x, mouse_y, g_panel_x + 278, g_panel_y + 7, 22, 22))
      return false; // theme next
   if(PointInRectPx(mouse_x, mouse_y, g_panel_x + 328, g_panel_y + 7, 22, 22))
      return false; // minimize
   return true;
}

void UpdateSetupVisuals()
{
   RefreshZoneColorsFromButtons();
   if(!g_setup_active)
   {
      SetSetupInfoText(StringFormat("Setup: none | Theme: %s", ThemeName()));
      return;
   }
   double entry = 0.0, sl = 0.0, tp = 0.0;
   if(!GetSetupPrices(entry, sl, tp))
   {
      ResetSetup();
      return;
   }
   // Cache for group drag
   g_cached_entry = entry;
   g_cached_sl    = sl;
   g_cached_tp    = tp;

   CreateOrMoveHLine(ObjName("setup_entry"), entry, g_entry_line_color, true, STYLE_DASH, 2);
   CreateOrMoveHLine(ObjName("setup_sl"),    sl,    g_sl_line_color,    true, STYLE_SOLID, 2);
   CreateOrMoveHLine(ObjName("setup_tp"),    tp,    g_tp_line_color,    true, STYLE_SOLID, 2);
   int seconds = PeriodSeconds(_Period);
   if(seconds <= 0)
      seconds = 60;
   datetime bar0 = iTime(_Symbol, _Period, 0);
   if(bar0 <= 0)
      bar0 = TimeCurrent();
   int visible_bars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   if(visible_bars <= 0)
      visible_bars = 100;
   int zone_bars = MathMax(6, visible_bars / 8);
   zone_bars = MathMin(zone_bars, MathMax(6, InpSetupProjectionBars));
   datetime left_time  = bar0 + seconds;
   datetime right_time = left_time + (seconds * zone_bars);
   double profit_top    = MathMax(entry, tp);
   double profit_bottom = MathMin(entry, tp);
   double loss_top      = MathMax(entry, sl);
   double loss_bottom   = MathMin(entry, sl);
   color profit_fill = ZoneFillColor(g_profit_zone_color);
   color loss_fill   = ZoneFillColor(g_loss_zone_color);
   CreateOrMoveRectangle(ObjName("setup_profit"), left_time, profit_top, right_time, profit_bottom, profit_fill);
   CreateOrMoveRectangle(ObjName("setup_loss"),   left_time, loss_top,   right_time, loss_bottom,   loss_fill);
   CreateOrMovePriceText(ObjName("setup_entry_text"), right_time, entry, StringFormat("ENTRY %s", PriceToText(_Symbol, entry)), g_entry_line_color);
   CreateOrMovePriceText(ObjName("setup_sl_text"),    right_time, sl,    StringFormat("SL %s", PriceToText(_Symbol, sl)),       g_sl_line_color);
   CreateOrMovePriceText(ObjName("setup_tp_text"),    right_time, tp,    StringFormat("TP %s", PriceToText(_Symbol, tp)),       g_tp_line_color);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double risk_points   = (point > 0.0 ? MathAbs(entry - sl) / point : 0.0);
   double reward_points = (point > 0.0 ? MathAbs(entry - tp) / point : 0.0);
   double rr            = (risk_points > 0.0 ? reward_points / risk_points : 0.0);
   double rr_price      = 0.0;
   if(g_setup_direction == PM_SETUP_BUY)
      rr_price = sl + MathAbs(entry - sl) * 0.28;
   else
      rr_price = sl - MathAbs(sl - entry) * 0.28;
   g_ui_sl_text = IntegerToString((int)MathRound(risk_points));
   g_ui_tp_text = IntegerToString((int)MathRound(reward_points));
   g_ui_rr_text = DoubleToString(rr, 2);
   if(!IsEditingObject(ObjName("edit_sl")))
      SetEditTextSafe(ObjName("edit_sl"), g_ui_sl_text);
   if(!IsEditingObject(ObjName("edit_tp")))
      SetEditTextSafe(ObjName("edit_tp"), g_ui_tp_text);
   if(!IsEditingObject(ObjName("edit_rr")))
      SetEditTextSafe(ObjName("edit_rr"), g_ui_rr_text);
   CreateOrMovePriceText(ObjName("setup_rr_text"), right_time, rr_price,
                         StringFormat("RR %.2f | R %.0f / W %.0f", rr, risk_points, reward_points),
                         clrWhiteSmoke);
   SetObjectTooltipSafe(ObjName("setup_sl"), MoneyTooltipText(false, entry, sl));
   SetObjectTooltipSafe(ObjName("setup_tp"), MoneyTooltipText(true, entry, tp));
   string validation_message;
   bool   valid = ValidateSetup(entry, sl, tp, validation_message);
   string info;
   if(valid)
   {
      info = StringFormat("%s | Mode %s | Entry %s | SL %s | TP %s | Risk %.0f pts | Reward %.0f pts | RR %.2f",
                          SetupSideText(), DetectSetupOrderModeText(entry),
                          PriceToText(_Symbol, entry), PriceToText(_Symbol, sl), PriceToText(_Symbol, tp),
                          risk_points, reward_points, rr);
   }
   else
   {
      info = validation_message;
   }
   SetSetupInfoText(info);
   ChartRedraw();
}

void CreateSetup(const ENUM_PM_SETUP_DIRECTION direction)
{
   RefreshZoneColorsFromButtons();
   double bid = 0.0, ask = 0.0;
   if(!GetBidAsk(_Symbol, bid, ask))
      return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;
   double entry = (direction == PM_SETUP_BUY ? ask : bid);
   double sl    = (direction == PM_SETUP_BUY ? entry - (InpDefaultSLPoints * point)
                                             : entry + (InpDefaultSLPoints * point));
   double tp    = (direction == PM_SETUP_BUY ? entry + (InpDefaultTPPoints * point)
                                             : entry - (InpDefaultTPPoints * point));
   g_setup_active    = true;
   g_setup_direction = direction;
   g_setup_symbol    = _Symbol;
   g_cached_entry    = entry;
   g_cached_sl       = sl;
   g_cached_tp       = tp;
   CreateOrMoveHLine(ObjName("setup_entry"), entry, g_entry_line_color, true, STYLE_DASH, 2);
   CreateOrMoveHLine(ObjName("setup_sl"),    sl,    g_sl_line_color,    true, STYLE_SOLID, 2);
   CreateOrMoveHLine(ObjName("setup_tp"),    tp,    g_tp_line_color,    true, STYLE_SOLID, 2);
   UpdateSetupVisuals();
}

bool PlaceOrderFromSetup()
{
   if(!g_setup_active)
   {
      SetSetupInfoText("No active setup. Click Buy Setup or Sell Setup first.");
      return false;
   }
   double entry = 0.0, sl = 0.0, tp = 0.0;
   if(!GetSetupPrices(entry, sl, tp))
      return false;
   string validation_message;
   if(!ValidateSetup(entry, sl, tp, validation_message))
   {
      SetSetupInfoText(validation_message);
      return false;
   }
   double volume = GetEditDouble(ObjName("edit_lot"), InpDefaultOrderVolume);
   if(!ValidateOrderVolume(volume, validation_message))
   {
      SetSetupInfoText(validation_message);
      return false;
   }
   double bid = 0.0, ask = 0.0;
   if(!GetBidAsk(_Symbol, bid, ask))
   {
      SetSetupInfoText("Cannot read live Bid/Ask.");
      return false;
   }
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.00001;
   long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_distance = stop_level * point;
   double tolerance    = point * 2.0;
   int digits          = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   entry = NormalizeDouble(entry, digits);
   sl    = NormalizeDouble(sl, digits);
   tp    = NormalizeDouble(tp, digits);
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.symbol       = _Symbol;
   request.magic        = (ulong)MathMax(0, InpOrderMagic);
   request.volume       = volume;
   request.deviation    = InpDeviationPoints;
   request.type_filling = GetFillingType(_Symbol);
   request.type_time    = ORDER_TIME_GTC;
   request.comment      = InpOrderComment;
   request.sl           = sl;
   request.tp           = tp;
   string mode_text = "";
   if(g_setup_direction == PM_SETUP_BUY)
   {
      if(entry < ask - tolerance)
      {
         if(stop_level > 0 && (ask - entry) < min_distance)
         {
            SetSetupInfoText("Buy Limit entry is too close to current Ask.");
            return false;
         }
         request.action = TRADE_ACTION_PENDING;
         request.type   = ORDER_TYPE_BUY_LIMIT;
         request.price  = entry;
         mode_text      = "BUY LIMIT";
      }
      else if(entry > ask + tolerance)
      {
         if(stop_level > 0 && (entry - ask) < min_distance)
         {
            SetSetupInfoText("Buy Stop entry is too close to current Ask.");
            return false;
         }
         request.action = TRADE_ACTION_PENDING;
         request.type   = ORDER_TYPE_BUY_STOP;
         request.price  = entry;
         mode_text      = "BUY STOP";
      }
      else
      {
         request.action = TRADE_ACTION_DEAL;
         request.type   = ORDER_TYPE_BUY;
         request.price  = ask;
         mode_text      = "BUY MARKET";
      }
   }
   else if(g_setup_direction == PM_SETUP_SELL)
   {
      if(entry > bid + tolerance)
      {
         if(stop_level > 0 && (entry - bid) < min_distance)
         {
            SetSetupInfoText("Sell Limit entry is too close to current Bid.");
            return false;
         }
         request.action = TRADE_ACTION_PENDING;
         request.type   = ORDER_TYPE_SELL_LIMIT;
         request.price  = entry;
         mode_text      = "SELL LIMIT";
      }
      else if(entry < bid - tolerance)
      {
         if(stop_level > 0 && (bid - entry) < min_distance)
         {
            SetSetupInfoText("Sell Stop entry is too close to current Bid.");
            return false;
         }
         request.action = TRADE_ACTION_PENDING;
         request.type   = ORDER_TYPE_SELL_STOP;
         request.price  = entry;
         mode_text      = "SELL STOP";
      }
      else
      {
         request.action = TRADE_ACTION_DEAL;
         request.type   = ORDER_TYPE_SELL;
         request.price  = bid;
         mode_text      = "SELL MARKET";
      }
   }
   else
   {
      SetSetupInfoText("No setup side selected.");
      return false;
   }
   bool sent = OrderSend(request, result);
   if(!sent)
   {
      string fail_text = StringFormat("OrderSend failed. Mode=%s | Error=%d", mode_text, GetLastError());
      SetSetupInfoText(fail_text);
      Print(fail_text);
      return false;
   }
   if(result.retcode != TRADE_RETCODE_DONE &&
      result.retcode != TRADE_RETCODE_DONE_PARTIAL &&
      result.retcode != TRADE_RETCODE_PLACED)
   {
      string fail_text = StringFormat("Order rejected. Mode=%s | Retcode=%d", mode_text, result.retcode);
      SetSetupInfoText(fail_text);
      Print(fail_text);
      return false;
   }
   ResetSetup();
   SetSetupInfoText(StringFormat("Placed successfully: %s | Lot %s", mode_text, DoubleToString(volume, VolumeDigitsFromStep(GetLotStep(_Symbol)))));
   return true;
}

void UpdatePanelStats()
{
   UpdateToggleButtons();
   if(g_setup_active)
      UpdateSetupVisuals();
   else
      ChartRedraw();
}

void CreatePanel()
{
   SavePanelState();
   DeletePanelUIObjects();

   if(g_panel_minimized)
   {
      CreateRectangleLabel(ObjName("bg"), 0, 0, PanelWidthMinimized(), PanelHeightMinimized(), InpPanelBgColor, InpPanelBorderColor);
      CreateRectangleLabel(ObjName("dragbar"), 0, 0, PanelWidthMinimized(), PanelHeightMinimized(), InpPanelBgColor, InpPanelBgColor);
      ObjectSetInteger(0, ObjName("dragbar"), OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, ObjName("dragbar"), OBJPROP_SELECTED, false);
      ObjectSetInteger(0, ObjName("dragbar"), OBJPROP_HIDDEN, false);
      CreateLabel(ObjName("title"), 10, 11, "Salari PM", C'255,215,0', 10, true);
      CreateButton(ObjName("btn_minimize"), 190, 9, 20, 20, "+", C'70,70,70');
      return;
   }

   // Deep shadow
   CreateRectangleLabel(ObjName("bg_shadow"), 3, 3, PanelWidthNormal(), PanelHeightNormal(), C'12,12,15', clrNONE);

   // Main panel
   CreateRectangleLabel(ObjName("bg"), 0, 0, PanelWidthNormal(), PanelHeightNormal(), InpPanelBgColor, InpPanelBorderColor);

   // Accent strip at top (steel blue line)
   CreateRectangleLabel(ObjName("accent_strip"), 0, 0, PanelWidthNormal(), 2, C'60,130,190', C'60,130,190');

   // Dragbar
   CreateRectangleLabel(ObjName("dragbar"), 0, 0, PanelWidthNormal(), 34, C'35,42,55', C'35,42,55');
   ObjectSetInteger(0, ObjName("dragbar"), OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, ObjName("dragbar"), OBJPROP_SELECTED, false);
   ObjectSetInteger(0, ObjName("dragbar"), OBJPROP_HIDDEN, false);

   // Title (gold)
   CreateLabel(ObjName("title"), 14, 10, "Salari Position Manager", C'255,215,0', 12, true);
   CreateLabel(ObjName("theme_label"), 190, 13, ThemeName(), C'180,190,210', 8, false);

   // Theme buttons + minimize
   CreateButton(ObjName("btn_theme_prev"), 252, 7, 22, 22, "<", C'60,70,85');
   CreateButton(ObjName("btn_theme_next"), 278, 7, 22, 22, ">", C'60,70,85');
   CreateButton(ObjName("btn_minimize"), 328, 7, 22, 22, "-", C'60,70,85');

   // Row 1: Setup buttons
   CreateButton(ObjName("btn_buy_setup"),  10, 38, 170, 30, "BUY SETUP",  InpBuyButtonColor);
   CreateButton(ObjName("btn_sell_setup"), 190, 38, 170, 30, "SELL SETUP", InpSellButtonColor);

   // Row 2: Lot controls + Place Order
   int R2 = 72;
   CreateButton(ObjName("btn_lot_minus"), 10, R2, 20, 20, "-", C'60,70,85');
   CreateEdit  (ObjName("edit_lot"), 32, R2+1, 60, 20, UseCachedOrDefault(g_ui_lot_text, DoubleToString(InpDefaultOrderVolume, VolumeDigitsFromStep(GetLotStep(_Symbol)))));
   CreateButton(ObjName("btn_lot_plus"), 94, R2, 20, 20, "+", C'60,70,85');
   CreateLabel(ObjName("lbl_lot"), 32, R2-9, "LOT", C'150,160,180', 8, false);
   CreateButton(ObjName("btn_send_order"), 190, R2, 170, 22, "Place Order", InpPrimaryButtonColor);

   // Row 3: Cancel / SL/TP / BreakEven / Clear Zones
   int R3 = 98;
   CreateButton(ObjName("btn_cancel_setup"), 10, R3, 82, 24, "Cancel", C'70,70,75');
   CreateButton(ObjName("btn_clear_zones"), 96, R3, 82, 24, "Clear", C'90,50,50');
   CreateButton(ObjName("btn_apply"), 182, R3, 82, 24, "SL/TP", InpPrimaryButtonColor);
   CreateButton(ObjName("btn_be_now"), 268, R3, 82, 24, "BreakEven", InpPrimaryButtonColor);

   // Row 4: Labels for SL / TP / RR
   int R4 = 128;
   CreateLabel(ObjName("lbl_sl"), 28, R4, "SL", C'150,160,180', 8, false);
   CreateLabel(ObjName("lbl_tp"), 126, R4, "TP", C'150,160,180', 8, false);
   CreateLabel(ObjName("lbl_rr"), 230, R4, "RR", C'255,215,0', 9, true);

   // Row 5: SL +/- / TP +/- / RR +/-   (aligned on same Y)
   int R5 = 142;
   int btn_h = 18;
   int edit_h = 20;
   int btn_w = 18;
   int edit_w = 52;

   CreateButton(ObjName("btn_sl_minus"), 10, R5+1, btn_w, btn_h, "-", C'60,70,85');
   CreateEdit  (ObjName("edit_sl"), 30, R5, edit_w, edit_h, UseCachedOrDefault(g_ui_sl_text, IntegerToString(InpDefaultSLPoints)));
   CreateButton(ObjName("btn_sl_plus"), 84, R5+1, btn_w, btn_h, "+", C'60,70,85');

   CreateButton(ObjName("btn_tp_minus"), 114, R5+1, btn_w, btn_h, "-", C'60,70,85');
   CreateEdit  (ObjName("edit_tp"), 134, R5, edit_w, edit_h, UseCachedOrDefault(g_ui_tp_text, IntegerToString(InpDefaultTPPoints)));
   CreateButton(ObjName("btn_tp_plus"), 188, R5+1, btn_w, btn_h, "+", C'60,70,85');

   CreateButton(ObjName("btn_rr_minus"), 218, R5+1, btn_w, btn_h, "-", C'60,70,85');
   CreateEdit  (ObjName("edit_rr"), 238, R5, edit_w, edit_h, UseCachedOrDefault(g_ui_rr_text, "2.00"), C'28,30,55');
   CreateButton(ObjName("btn_rr_plus"), 292, R5+1, btn_w, btn_h, "+", C'60,70,85');

   // Row 6: Labels for Part% / BE Trig / BE Lock / Trail
   int R6 = 168;
   CreateLabel(ObjName("lbl_partial"), 10, R6, "Part%", C'150,160,180', 8, false);
   CreateLabel(ObjName("lbl_be_trig"), 94, R6, "BE Trig", C'150,160,180', 8, false);
   CreateLabel(ObjName("lbl_be_lock"), 178, R6, "BE Lock", C'150,160,180', 8, false);
   CreateLabel(ObjName("lbl_trail"), 262, R6, "Trail", C'150,160,180', 8, false);

   // Row 7: Part% / BE Trig +/- / BE Lock +/- / Trail +/-
   int R7 = 182;
   CreateEdit(ObjName("edit_partial"), 10, R7, 60, edit_h, UseCachedOrDefault(g_ui_partial_text, DoubleToString(InpDefaultPartialPct, 1)));

   CreateButton(ObjName("btn_be_trig_minus"), 76, R7+1, btn_w, btn_h, "-", C'60,70,85');
   CreateEdit  (ObjName("edit_be_trig"), 96, R7, 48, edit_h, UseCachedOrDefault(g_ui_be_trig_text, IntegerToString(InpDefaultBETrigger)));
   CreateButton(ObjName("btn_be_trig_plus"), 146, R7+1, btn_w, btn_h, "+", C'60,70,85');

   CreateButton(ObjName("btn_be_lock_minus"), 162, R7+1, btn_w, btn_h, "-", C'60,70,85');
   CreateEdit  (ObjName("edit_be_lock"), 182, R7, 48, edit_h, UseCachedOrDefault(g_ui_be_lock_text, IntegerToString(InpDefaultBELock)));
   CreateButton(ObjName("btn_be_lock_plus"), 232, R7+1, btn_w, btn_h, "+", C'60,70,85');

   CreateButton(ObjName("btn_trail_minus"), 248, R7+1, btn_w, btn_h, "-", C'60,70,85');
   CreateEdit  (ObjName("edit_trail"), 268, R7, 48, edit_h, UseCachedOrDefault(g_ui_trail_text, IntegerToString(InpDefaultTrailPoints)));
   CreateButton(ObjName("btn_trail_plus"), 318, R7+1, btn_w, btn_h, "+", C'60,70,85');

   // Row 8: Toggle / Action buttons
   int R8 = 210;
   CreateButton(ObjName("btn_auto_be"), 10, R8, 110, 24, "Auto BE: OFF", C'70,70,75');
   CreateButton(ObjName("btn_trail"), 126, R8, 110, 24, "Trailing: OFF", C'70,70,75');
   CreateButton(ObjName("btn_partial"), 242, R8, 110, 24, "Partial", InpPrimaryButtonColor);

   // Row 9: Close buttons
   int R9 = 240;
   CreateButton(ObjName("btn_close_buy"), 10, R9, 110, 24, "Close Buy",  InpBuyButtonColor);
   CreateButton(ObjName("btn_close_sell"), 126, R9, 110, 24, "Close Sell", InpSellButtonColor);
   CreateButton(ObjName("btn_close_all"), 242, R9, 110, 24, "Close All",  InpDangerButtonColor);
}

void ApplySLTPToMatches(const int sl_points, const int tp_points)
{
   ulong tickets[];
   int count = CollectMatchingTickets(tickets);
   if(count <= 0)
      return;
   for(int i = 0; i < count; i++)
   {
      ulong ticket = tickets[i];
      if(!PositionSelectByTicket(ticket))
         continue;
      string symbol           = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price       = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl       = PositionGetDouble(POSITION_SL);
      double current_tp       = PositionGetDouble(POSITION_TP);
      double point            = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double new_sl = current_sl;
      double new_tp = current_tp;
      if(sl_points > 0)
      {
         if(type == POSITION_TYPE_BUY)
            new_sl = open_price - (sl_points * point);
         else
            new_sl = open_price + (sl_points * point);
      }
      if(tp_points > 0)
      {
         if(type == POSITION_TYPE_BUY)
            new_tp = open_price + (tp_points * point);
         else
            new_tp = open_price - (tp_points * point);
      }
      ModifyPositionByTicket(ticket, new_sl, new_tp);
   }
}

void MoveMatchesToBreakEven(const int lock_points)
{
   ulong tickets[];
   int count = CollectMatchingTickets(tickets);
   if(count <= 0)
      return;
   for(int i = 0; i < count; i++)
   {
      ulong ticket = tickets[i];
      if(!PositionSelectByTicket(ticket))
         continue;
      string symbol           = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price       = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl       = PositionGetDouble(POSITION_SL);
      double current_tp       = PositionGetDouble(POSITION_TP);
      double point            = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double bid = 0.0, ask = 0.0;
      if(!GetBidAsk(symbol, bid, ask))
         continue;
      double new_sl = 0.0;
      if(type == POSITION_TYPE_BUY)
      {
         if(bid <= open_price)
            continue;
         new_sl = open_price + (lock_points * point);
         if(current_sl != 0.0 && current_sl >= new_sl - (point * 0.5))
            continue;
      }
      else
      {
         if(ask >= open_price)
            continue;
         new_sl = open_price - (lock_points * point);
         if(current_sl != 0.0 && current_sl <= new_sl + (point * 0.5))
            continue;
      }
      ModifyPositionByTicket(ticket, new_sl, current_tp);
   }
}

void RunAutoBreakEven()
{
   int trigger_points = GetEditInt(ObjName("edit_be_trig"), InpDefaultBETrigger);
   int lock_points    = GetEditInt(ObjName("edit_be_lock"), InpDefaultBELock);
   if(trigger_points <= 0)
      return;
   ulong tickets[];
   int count = CollectMatchingTickets(tickets);
   if(count <= 0)
      return;
   for(int i = 0; i < count; i++)
   {
      ulong ticket = tickets[i];
      if(!PositionSelectByTicket(ticket))
         continue;
      string symbol           = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price       = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl       = PositionGetDouble(POSITION_SL);
      double current_tp       = PositionGetDouble(POSITION_TP);
      double point            = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double bid = 0.0, ask = 0.0;
      if(!GetBidAsk(symbol, bid, ask))
         continue;
      if(type == POSITION_TYPE_BUY)
      {
         if((bid - open_price) < (trigger_points * point))
            continue;
         double new_sl = open_price + (lock_points * point);
         if(current_sl != 0.0 && current_sl >= new_sl - (point * 0.5))
            continue;
         ModifyPositionByTicket(ticket, new_sl, current_tp);
      }
      else
      {
         if((open_price - ask) < (trigger_points * point))
            continue;
         double new_sl = open_price - (lock_points * point);
         if(current_sl != 0.0 && current_sl <= new_sl + (point * 0.5))
            continue;
         ModifyPositionByTicket(ticket, new_sl, current_tp);
      }
   }
}

void RunTrailingStop()
{
   int trail_points = GetEditInt(ObjName("edit_trail"), InpDefaultTrailPoints);
   if(trail_points <= 0)
      return;
   ulong tickets[];
   int count = CollectMatchingTickets(tickets);
   if(count <= 0)
      return;
   for(int i = 0; i < count; i++)
   {
      ulong ticket = tickets[i];
      if(!PositionSelectByTicket(ticket))
         continue;
      string symbol           = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price       = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl       = PositionGetDouble(POSITION_SL);
      double current_tp       = PositionGetDouble(POSITION_TP);
      double point            = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double bid = 0.0, ask = 0.0;
      if(!GetBidAsk(symbol, bid, ask))
         continue;
      if(type == POSITION_TYPE_BUY)
      {
         if((bid - open_price) < (trail_points * point))
            continue;
         double candidate_sl = bid - (trail_points * point);
         if(current_sl != 0.0 && candidate_sl <= current_sl + (InpTrailStepPoints * point))
            continue;
         ModifyPositionByTicket(ticket, candidate_sl, current_tp);
      }
      else
      {
         if((open_price - ask) < (trail_points * point))
            continue;
         double candidate_sl = ask + (trail_points * point);
         if(current_sl != 0.0 && candidate_sl >= current_sl - (InpTrailStepPoints * point))
            continue;
         ModifyPositionByTicket(ticket, candidate_sl, current_tp);
      }
   }
}

void PartialCloseMatches(const double percent)
{
   if(percent <= 0.0)
      return;
   ulong tickets[];
   int count = CollectMatchingTickets(tickets);
   if(count <= 0)
      return;
   for(int i = 0; i < count; i++)
   {
      ulong ticket = tickets[i];
      if(!PositionSelectByTicket(ticket))
         continue;
      string symbol  = PositionGetString(POSITION_SYMBOL);
      double volume  = PositionGetDouble(POSITION_VOLUME);
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double close_volume = volume * (percent / 100.0);
      close_volume = NormalizeVolumeToStep(symbol, close_volume);
      if(close_volume < min_lot - 1e-8)
         continue;
      double remainder = volume - close_volume;
      if(remainder > 1e-8 && remainder < min_lot - 1e-8)
      {
         close_volume = NormalizeVolumeToStep(symbol, volume - min_lot);
      }
      if(close_volume > 0.0)
         ReducePositionVolume(ticket, close_volume);
   }
}

void CloseMatchesByType(const ENUM_POSITION_TYPE wanted_type)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(!SelectedPositionMatchesFilters())
         continue;
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == wanted_type)
         ClosePositionFully(ticket);
   }
}

void CloseAllMatches()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(!SelectedPositionMatchesFilters())
         continue;
      ClosePositionFully(ticket);
   }
}

int OnInit()
{
   trade.SetAsyncMode(false);
   trade.SetDeviationInPoints((int)InpDeviationPoints);
   trade.SetExpertMagicNumber((ulong)MathMax(0, InpOrderMagic));
   if(!LoadPanelPosition())
      LeftCenterPanelOnChart();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ApplyColorTheme(0);
   RestoreSetupFromObjects();
   CreatePanel();
   if(g_setup_active)
      UpdateSetupVisuals();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   SavePanelPosition();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
   if(reason == REASON_CHARTCHANGE)
      DeletePanelUIObjects();
   else
      DeleteAllPMObjects();
}

void OnTick()
{
   if(g_auto_be_enabled)
      RunAutoBreakEven();
   if(g_trailing_enabled)
      RunTrailingStop();
}

void OnTimer()
{
   ApplyRRFromPanelInput();
   UpdatePanelStats();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   static bool prev_left_pressed = false;
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      int mouse_x = (int)lparam;
      int mouse_y = (int)dparam;
      int state   = (int)StringToInteger(sparam);
      bool left_pressed = ((state & 1) == 1);
      if(left_pressed && !prev_left_pressed && CanStartPanelDrag(mouse_x, mouse_y))
      {
         g_panel_dragging = true;
         g_drag_offset_x  = mouse_x - g_panel_x;
         g_drag_offset_y  = mouse_y - g_panel_y;
      }
      if(g_panel_dragging && left_pressed)
      {
         MovePanelTo(mouse_x - g_drag_offset_x, mouse_y - g_drag_offset_y);
         prev_left_pressed = left_pressed;
         return;
      }
      if(g_panel_dragging && !left_pressed)
         g_panel_dragging = false;
      prev_left_pressed = left_pressed;
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == ObjName("edit_rr"))
      {
         ApplyRRFromPanelInput();
         return;
      }
      if(sparam == ObjName("edit_sl") || sparam == ObjName("edit_tp"))
      {
         ApplySLTPFromEdits();
         return;
      }
   }

   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      // Group drag: when Entry line is dragged, shift SL and TP together
      if(sparam == ObjName("setup_entry"))
      {
         if(g_setup_active && g_cached_entry != 0.0)
         {
            double new_entry = ObjectGetDouble(0, ObjName("setup_entry"), OBJPROP_PRICE);
            double delta = new_entry - g_cached_entry;
            if(MathAbs(delta) > 0.0)
            {
               double new_sl = g_cached_sl + delta;
               double new_tp = g_cached_tp + delta;
               ObjectSetDouble(0, ObjName("setup_sl"), OBJPROP_PRICE, new_sl);
               ObjectSetDouble(0, ObjName("setup_tp"), OBJPROP_PRICE, new_tp);
            }
         }
         UpdateSetupVisuals();
         return;
      }
      if(sparam == ObjName("setup_sl") || sparam == ObjName("setup_tp"))
      {
         UpdateSetupVisuals();
         return;
      }
      if(sparam == ObjName("dragbar"))
      {
         int new_x = (int)ObjectGetInteger(0, ObjName("dragbar"), OBJPROP_XDISTANCE);
         int new_y = (int)ObjectGetInteger(0, ObjName("dragbar"), OBJPROP_YDISTANCE);
         MovePanelTo(new_x, new_y);
         return;
      }
   }

   if(id != CHARTEVENT_OBJECT_CLICK)
      return;
   if(StringFind(sparam, PREFIX) != 0)
      return;
   if(IsSetupObjectName(sparam))
      return;
   if(!IsPanelButtonName(sparam))
      return;

   if(sparam == ObjName("btn_minimize"))
   {
      g_panel_minimized = !g_panel_minimized;
      CreatePanel();
      return;
   }
   else if(sparam == ObjName("btn_buy_setup"))
   {
      CreateSetup(PM_SETUP_BUY);
   }
   else if(sparam == ObjName("btn_sell_setup"))
   {
      CreateSetup(PM_SETUP_SELL);
   }
   else if(sparam == ObjName("btn_send_order"))
   {
      PlaceOrderFromSetup();
   }
   else if(sparam == ObjName("btn_lot_minus"))
   {
      AdjustLotField(-1);
   }
   else if(sparam == ObjName("btn_lot_plus"))
   {
      AdjustLotField(1);
   }
   else if(sparam == ObjName("btn_sl_minus"))
   {
      AdjustSLField(-1);
   }
   else if(sparam == ObjName("btn_sl_plus"))
   {
      AdjustSLField(1);
   }
   else if(sparam == ObjName("btn_tp_minus"))
   {
      AdjustTPField(-1);
   }
   else if(sparam == ObjName("btn_tp_plus"))
   {
      AdjustTPField(1);
   }
   else if(sparam == ObjName("btn_rr_minus"))
   {
      AdjustRRField(-1);
   }
   else if(sparam == ObjName("btn_rr_plus"))
   {
      AdjustRRField(1);
   }
   else if(sparam == ObjName("btn_be_trig_minus"))
   {
      AdjustBETrigField(-1);
   }
   else if(sparam == ObjName("btn_be_trig_plus"))
   {
      AdjustBETrigField(1);
   }
   else if(sparam == ObjName("btn_be_lock_minus"))
   {
      AdjustBELockField(-1);
   }
   else if(sparam == ObjName("btn_be_lock_plus"))
   {
      AdjustBELockField(1);
   }
   else if(sparam == ObjName("btn_trail_minus"))
   {
      AdjustTrailField(-1);
   }
   else if(sparam == ObjName("btn_trail_plus"))
   {
      AdjustTrailField(1);
   }
   else if(sparam == ObjName("btn_theme_prev"))
   {
      CycleTheme(-1);
   }
   else if(sparam == ObjName("btn_theme_next"))
   {
      CycleTheme(1);
   }
   else if(sparam == ObjName("btn_cancel_setup"))
   {
      ResetSetup();
   }
   else if(sparam == ObjName("btn_clear_zones"))
   {
      ResetSetup();
   }
   else if(sparam == ObjName("btn_apply"))
   {
      int sl_points = GetEditInt(ObjName("edit_sl"), InpDefaultSLPoints);
      int tp_points = GetEditInt(ObjName("edit_tp"), InpDefaultTPPoints);
      ApplySLTPToMatches(sl_points, tp_points);
   }
   else if(sparam == ObjName("btn_be_now"))
   {
      int lock_points = GetEditInt(ObjName("edit_be_lock"), InpDefaultBELock);
      MoveMatchesToBreakEven(lock_points);
   }
   else if(sparam == ObjName("btn_auto_be"))
   {
      g_auto_be_enabled = !g_auto_be_enabled;
      UpdateToggleButtons();
   }
   else if(sparam == ObjName("btn_trail"))
   {
      g_trailing_enabled = !g_trailing_enabled;
      UpdateToggleButtons();
   }
   else if(sparam == ObjName("btn_partial"))
   {
      double percent = GetEditDouble(ObjName("edit_partial"), InpDefaultPartialPct);
      PartialCloseMatches(percent);
   }
   else if(sparam == ObjName("btn_refresh"))
   {
      UpdatePanelStats();
   }
   else if(sparam == ObjName("btn_close_buy"))
   {
      CloseMatchesByType(POSITION_TYPE_BUY);
   }
   else if(sparam == ObjName("btn_close_sell"))
   {
      CloseMatchesByType(POSITION_TYPE_SELL);
   }
   else if(sparam == ObjName("btn_close_all"))
   {
      CloseAllMatches();
   }

   if(ObjectFind(0, sparam) != -1)
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   UpdatePanelStats();
}

