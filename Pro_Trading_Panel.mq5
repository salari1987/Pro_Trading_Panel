//+------------------------------------------------------------------+
//| Professional_Trading_Panel.mq5                                    |
//| پنل ترید حرفه‌ای با Setup گرافیکی به سبک تریدینگ ویو              |
//+------------------------------------------------------------------+
#property copyright "Pro Trading Panel"
#property version   "3.10"
#property description "Professional Trading Panel with TradingView-style visual setup"

#property strict

#include <Trade\Trade.mqh>

CTrade trade;

// --- موقعیت پنل ---
int panelX = 10;
int panelY = 80;
int panelWidth = 270;
int panelHeight = 480;

// --- رنگ‌ها ---
color bgMain         = C'20,20,27';
color bgHeader       = C'30,30,42';
color btnBuyColor    = C'60,179,113';  // MediumSeaGreen
color btnSellColor   = C'220,20,60';   // Crimson
color btnNormalColor = C'45,45,58';
color btnConfirmColor = C'40,100,180';
color textWhite      = clrWhite;
color textGray       = C'160,160,170';
color textGold       = C'242,193,46';
color borderLine     = C'55,55,70';

// --- رنگ‌های خطوط Setup (سبک تریدینگ ویو) ---
color setupEntryColor  = C'255,200,50';   // زرد طلایی خط Entry
color setupSLColor     = C'220,20,60';    // Crimson SL
color setupTPColor     = C'60,179,113';   // MediumSeaGreen TP
color setupProfitFill  = C'40,160,80';    // سبز ناحیه سود
color setupLossFill    = C'200,20,50';    // پر قرمز ناحیه ضرر (Crimson)

// --- تنظیمات ورودی ---
input group "═══ تنظیمات مدیریت ریسک ═══"
input double DefaultLot   = 0.1;
input double LotStep      = 0.01;
input int    DefaultTP    = 300;
input int    DefaultSL    = 150;

input group "═══ تنظیمات سیستم هوشمند ═══"
input bool   UseTrailing  = false;
input int    TrailingStop = 200;
input int    BreakEvenPips = 200;

// --- پیشوند اشیاء ---
string prefix = "ProPanel_";

// --- متغیرهای پنل ---
double currentLot;
int    currentTP, currentSL;
bool   trailingState = false;
bool   breakEvenState = false;
int    g_trailStop;
int    g_bePips;

// --- متغیرهای Setup گرافیکی ---
bool   g_setup_active     = false;
int    g_setup_direction  = 0;   // +1 = BUY, -1 = SELL
double g_entry_price      = 0.0;
double g_sl_price         = 0.0;
double g_tp_price         = 0.0;
double g_cached_entry     = 0.0;
double g_cached_sl        = 0.0;
double g_cached_tp        = 0.0;
datetime g_setup_time     = 0;
bool     g_panel_minimized = false;
int      g_zone_counter = 0;  // کانتر برای ایجاد زون‌های نامحدود
int      g_confirmed_cnt = 0; // تعداد ستاپ‌های تایید شده

//+------------------------------------------------------------------+
//| Helper: اسم آبجکت روی چارت                                       |
//+------------------------------------------------------------------+
string ObjName(const string suffix)
{
   return "Setup_" + suffix;
}

//+------------------------------------------------------------------+
//| Helper: قیمت به متن                                              |
//+------------------------------------------------------------------+
string PriceToText(const string symbol, const double price)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return DoubleToString(price, digits);
}

//+------------------------------------------------------------------+
//| Helper: محاسبه سود/ضرر به دلار                                   |
//+------------------------------------------------------------------+
string MoneyToText(const double entry, const double level)
{
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_size <= 0.0 || tick_value <= 0.0)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0) return "---";
      tick_size = point;
      tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tick_value <= 0.0) return "---";
   }
   double money = (MathAbs(level - entry) / tick_size) * tick_value * currentLot;
   string ccy = AccountInfoString(ACCOUNT_CURRENCY);
   return StringFormat("%s %.2f", ccy, money);
}

//+------------------------------------------------------------------+
//| پاک کردن آبجکت اگه وجود داره                                     |
//+------------------------------------------------------------------+
void DeleteIfExists(const string name)
{
   if(ObjectFind(0, name) != -1)
      ObjectDelete(0, name);
}

//+------------------------------------------------------------------+
//| پاک کردن تمام آبجکت‌های Setup                                    |
//+------------------------------------------------------------------+
void DeleteSetupObjects()
{
   DeleteIfExists(ObjName("entry_line"));
   DeleteIfExists(ObjName("sl_line"));
   DeleteIfExists(ObjName("tp_line"));
   DeleteIfExists(ObjName("profit_zone"));
   DeleteIfExists(ObjName("loss_zone"));
   DeleteIfExists(ObjName("entry_label"));
   DeleteIfExists(ObjName("sl_label"));
   DeleteIfExists(ObjName("tp_label"));
   DeleteIfExists(ObjName("rr_label"));
}

//+------------------------------------------------------------------+
//| ریست کردن Setup                                                  |
//+------------------------------------------------------------------+
void ResetSetup()
{
   g_setup_active    = false;
   g_setup_direction = 0;
   g_entry_price     = 0.0;
   g_sl_price        = 0.0;
   g_tp_price        = 0.0;
   g_cached_entry    = 0.0;
   g_cached_sl       = 0.0;
   g_cached_tp       = 0.0;
   g_setup_time      = 0;

   DeleteSetupObjects();

   // تغییر رنگ دکمه‌های Buy/Sell به حالت عادی
   ObjectSetInteger(0, prefix + "BtnBuy", OBJPROP_BGCOLOR, btnBuyColor);
   ObjectSetString(0, prefix + "BtnBuy", OBJPROP_TEXT, "BUY ▲");
   ObjectSetInteger(0, prefix + "BtnSell", OBJPROP_BGCOLOR, btnSellColor);
   ObjectSetString(0, prefix + "BtnSell", OBJPROP_TEXT, "SELL ▼");

   // پاک کردن متن Order Mode
   ObjectSetString(0, prefix + "OrderMode", OBJPROP_TEXT, "");

   // ریست دکمه Confirm
   ObjectSetInteger(0, prefix + "BtnConfirm", OBJPROP_BGCOLOR, btnConfirmColor);
   ObjectSetString(0, prefix + "BtnConfirm", OBJPROP_TEXT, "✅ Confirm");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ایجاد خط محدود (horizontal segment در محدوده پروجکشن)            |
//+------------------------------------------------------------------+
bool CreateOrMoveHLineSegment(const string name, const double price, const color clr,
                              const bool selectable, const int style, const int width,
                              const datetime t1, const datetime t2)
{
   // از OBJ_TREND استفاده می‌کنیم و دو سر خط رو محدود می‌کنیم
   bool exists = (ObjectFind(0, name) != -1);
   bool was_selected = false;

   if(!exists)
   {
      if(!ObjectCreate(0, name, OBJ_TREND, 0, 0, 0, 0, 0))
         return false;
   }
   else
   {
      was_selected = (bool)ObjectGetInteger(0, name, OBJPROP_SELECTED);
   }

   ObjectMove(0, name, 0, t1, price);
   ObjectMove(0, name, 1, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, was_selected);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   return true;
}

//+------------------------------------------------------------------+
//| ایجاد مستطیل (ناحیه سود/ضرر)                                     |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| ایجاد متن روی چارت                                               |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| محاسبه محدوده زمانی پروجکشن                                     |
//+------------------------------------------------------------------+
void GetProjectionTimes(datetime &left_time, datetime &right_time)
{
   int seconds = PeriodSeconds(_Period);
   if(seconds <= 0) seconds = 60;

   // آخرین کندل کامل شده (بار 1) - آخرین کندل بسته
   datetime bar_last = iTime(_Symbol, _Period, 1);
   if(bar_last <= 0) bar_last = TimeCurrent();

   // خطوط و باکس‌ها دقیقاً از خود آخرین کندل شروع بشن
   left_time  = bar_last;  // از ابتدای آخرین کندل
   right_time = bar_last + seconds * 6;  // 6 بار جلو
}

//+------------------------------------------------------------------+
//| آپدیت خطوط Setup از مقادیر پنل (SL/TP)                          |
//+------------------------------------------------------------------+
void UpdateSetupFromPanel()
{
   if(!g_setup_active)
      return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(g_setup_direction == 1) // BUY
   {
      g_sl_price = NormalizeDouble(g_entry_price - currentSL * point, digits);
      g_tp_price = NormalizeDouble(g_entry_price + currentTP * point, digits);
   }
   else // SELL
   {
      g_sl_price = NormalizeDouble(g_entry_price + currentSL * point, digits);
      g_tp_price = NormalizeDouble(g_entry_price - currentTP * point, digits);
   }

   // به‌روزرسانی خطوط روی چارت
   datetime left_time, right_time;
   GetProjectionTimes(left_time, right_time);

   CreateOrMoveHLineSegment(ObjName("sl_line"), g_sl_price, setupSLColor, true, STYLE_SOLID, 2, left_time, right_time);
   CreateOrMoveHLineSegment(ObjName("tp_line"), g_tp_price, setupTPColor, true, STYLE_SOLID, 2, left_time, right_time);

   UpdateSetupVisuals();
}

//+------------------------------------------------------------------+
//| بروزرسانی نمایش گرافیکی Setup                                    |
//+------------------------------------------------------------------+
void UpdateSetupVisuals()
{
   if(!g_setup_active)
      return;

   double entry = g_entry_price;
   double sl    = g_sl_price;
   double tp    = g_tp_price;

   if(entry == 0.0 || sl == 0.0 || tp == 0.0)
   {
      ResetSetup();
      return;
   }

   // کش کردن قیمت‌ها برای Group Drag
   g_cached_entry = entry;
   g_cached_sl    = sl;
   g_cached_tp    = tp;

   // محاسبه محدوده زمانی
   datetime left_time, right_time;
   GetProjectionTimes(left_time, right_time);

   // خطوط اصلی - محدود به محدوده پروجکشن
   CreateOrMoveHLineSegment(ObjName("entry_line"), entry, setupEntryColor, true, STYLE_DASH, 2, left_time, right_time);
   CreateOrMoveHLineSegment(ObjName("sl_line"),    sl,    setupSLColor,    true, STYLE_SOLID, 2, left_time, right_time);
   CreateOrMoveHLineSegment(ObjName("tp_line"),    tp,    setupTPColor,    true, STYLE_SOLID, 2, left_time, right_time);

   // نواحی سود و ضرر
   double profit_top    = MathMax(entry, tp);
   double profit_bottom = MathMin(entry, tp);
   double loss_top      = MathMax(entry, sl);
   double loss_bottom   = MathMin(entry, sl);

   CreateOrMoveRectangle(ObjName("profit_zone"), left_time, profit_top, right_time, profit_bottom, setupProfitFill);
   CreateOrMoveRectangle(ObjName("loss_zone"),   left_time, loss_top,   right_time, loss_bottom,   setupLossFill);

   // برچسب‌های قیمت + سود/ضرر به دلار
   CreateOrMovePriceText(ObjName("entry_label"), right_time, entry,
                         StringFormat("Entry %s", PriceToText(_Symbol, entry)), setupEntryColor);
   CreateOrMovePriceText(ObjName("sl_label"),    right_time, sl - (entry - sl) * 0.3,
                         StringFormat("SL %s", MoneyToText(entry, sl)), setupSLColor);
   CreateOrMovePriceText(ObjName("tp_label"),    right_time, tp + (tp - entry) * 0.3,
                         StringFormat("TP %s", MoneyToText(entry, tp)), setupTPColor);

   // محاسبه و نمایش RR (Risk/Reward) روی چارت
   double risk_pts   = MathAbs(entry - sl);
   double reward_pts = MathAbs(entry - tp);
   double rr_value   = (risk_pts > 0.0) ? reward_pts / risk_pts : 0.0;

   double rr_price = 0.0;
   if(g_setup_direction == 1)
      rr_price = sl + (entry - sl) * 0.35;
   else if(g_setup_direction == -1)
      rr_price = tp + (entry - tp) * 0.35;

   color rr_color = (rr_value >= 1.0) ? setupTPColor : setupSLColor;
   string rr_text = StringFormat("R:R %.2f", rr_value);
   CreateOrMovePriceText(ObjName("rr_label"), right_time, rr_price, rr_text, rr_color);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ایجاد Setup گرافیکی با کلیک روی Buy/Sell                         |
//+------------------------------------------------------------------+
void CreateGraphicalSetup(const int direction)
{
   if(g_setup_active)
      ResetSetup();

   double bid = 0.0, ask = 0.0;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   bid = tick.bid;
   ask = tick.ask;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;

   double entry, sl, tp;

   if(direction == 1)
   {
      entry = ask;
      sl    = entry - (currentSL * point);
      tp    = entry + (currentTP * point);
   }
   else
   {
      entry = bid;
      sl    = entry + (currentSL * point);
      tp    = entry - (currentTP * point);
   }

   g_setup_active    = true;
   g_setup_direction = direction;
   g_entry_price     = entry;
   g_sl_price        = sl;
   g_tp_price        = tp;
   g_cached_entry    = entry;
   g_cached_sl       = sl;
   g_cached_tp       = tp;

   ObjectSetInteger(0, prefix + "BtnConfirm", OBJPROP_BGCOLOR, btnConfirmColor);
   ObjectSetString(0, prefix + "BtnConfirm", OBJPROP_TEXT, "✅ Confirm");

   UpdateSetupVisuals();

   ObjectSetString(0, prefix + "BtnBuy", OBJPROP_TEXT, (direction == 1) ? "BUY PENDING" : "BUY ▲");
   ObjectSetString(0, prefix + "BtnSell", OBJPROP_TEXT, (direction == 1) ? "SELL ▼" : "SELL PENDING");

   if(direction == 1)
      ObjectSetInteger(0, prefix + "BtnBuy", OBJPROP_BGCOLOR, C'60,179,113');
   else
      ObjectSetInteger(0, prefix + "BtnSell", OBJPROP_BGCOLOR, C'220,20,60');

   string mode = DetectOrderMode(entry);
   ObjectSetString(0, prefix + "OrderMode", OBJPROP_TEXT, mode);
}

//+------------------------------------------------------------------+
//| ذخیره ستاپ تایید شده برای بازیابی بعد از تغییر تایم‌فریم         |
//+------------------------------------------------------------------+
void SaveConfirmedSetup(const int idx, const int dir, const double entry, const double sl, const double tp)
{
   string base = "ProPanel_Conf_" + IntegerToString(idx) + "_";
   GlobalVariableSet(base + "Dir", dir);
   GlobalVariableSet(base + "Entry", entry);
   GlobalVariableSet(base + "SL", sl);
   GlobalVariableSet(base + "TP", tp);
}

bool LoadConfirmedSetup(const int idx, int &dir, double &entry, double &sl, double &tp)
{
   string base = "ProPanel_Conf_" + IntegerToString(idx) + "_";
   if(!GlobalVariableCheck(base + "Dir")) return false;
   dir   = (int)GlobalVariableGet(base + "Dir");
   entry = GlobalVariableGet(base + "Entry");
   sl    = GlobalVariableGet(base + "SL");
   tp    = GlobalVariableGet(base + "TP");
   return true;
}

void RestoreConfirmedSetups()
{
   if(!GlobalVariableCheck("ProPanel_ConfCount")) return;
   int cnt = (int)GlobalVariableGet("ProPanel_ConfCount");
   if(cnt <= 0) return;

   for(int idx = 0; idx < cnt; idx++)
   {
      int dir = 0;
      double entry = 0, sl = 0, tp = 0;
      if(!LoadConfirmedSetup(idx, dir, entry, sl, tp)) continue;

      datetime left_time, right_time;
      GetProjectionTimes(left_time, right_time);

      CreateOrMoveHLineSegment("Conf_Entry_" + IntegerToString(idx), entry, C'180,140,40', false, STYLE_DASH, 1, left_time, right_time);
      CreateOrMoveHLineSegment("Conf_SL_" + IntegerToString(idx),    sl,    C'180,30,50',  false, STYLE_SOLID, 1, left_time, right_time);
      CreateOrMoveHLineSegment("Conf_TP_" + IntegerToString(idx),    tp,    C'50,150,80',  false, STYLE_SOLID, 1, left_time, right_time);

      double profit_top    = MathMax(entry, tp);
      double profit_bottom = MathMin(entry, tp);
      double loss_top      = MathMax(entry, sl);
      double loss_bottom   = MathMin(entry, sl);

      CreateOrMoveRectangle("Conf_Profit_" + IntegerToString(idx), left_time, profit_top, right_time, profit_bottom, C'30,120,50');
      CreateOrMoveRectangle("Conf_Loss_" + IntegerToString(idx),   left_time, loss_top,   right_time, loss_bottom,   C'140,30,40');
   }
   g_confirmed_cnt = cnt;
}

//+------------------------------------------------------------------+
//| ایجاد زون خرید/فروش (منطقه رنگی قابل درگ روی چارت)              |
//+------------------------------------------------------------------+
void CreateZone(const int direction)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;

   datetime left_time, right_time;
   GetProjectionTimes(left_time, right_time);
   // دوبرابر کردن عرض زون
   right_time += (right_time - left_time);

   // محاسبه وسط چارت برای قرارگیری زون
   double chart_high = ChartGetDouble(0, CHART_PRICE_MAX);
   double chart_low  = ChartGetDouble(0, CHART_PRICE_MIN);
   double mid_price  = (chart_high + chart_low) / 2.0;

   string zone_name = (direction == 1) ? "BuyZone" : "SellZone";
   color border_color = (direction == 1) ? C'60,179,113' : C'200,20,50';
   color fill_color   = (direction == 1) ? C'30,100,55' : C'100,15,25';

   double base_price = mid_price;
   double zone_height = point * 100;

   double p1 = base_price - zone_height;
   double p2 = base_price + zone_height;

   g_zone_counter++;
   string full_name = "Zone_" + zone_name + "_" + IntegerToString(g_zone_counter);

   if(!ObjectCreate(0, full_name, OBJ_RECTANGLE, 0, left_time, p1, right_time, p2))
      return;

   ObjectSetInteger(0, full_name, OBJPROP_COLOR, border_color);
   ObjectSetInteger(0, full_name, OBJPROP_FILL, true);
   ObjectSetInteger(0, full_name, OBJPROP_BACK, true);
   ObjectSetInteger(0, full_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, full_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, full_name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, full_name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, full_name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, full_name, OBJPROP_TOOLTIP, (direction == 1) ? "Buy Zone - Drag me!" : "Sell Zone - Drag me!");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| تأیید و ارسال سفارش از روی Setup گرافیکی                         |
//+------------------------------------------------------------------+
void ConfirmSetupOrder()
{
   if(!g_setup_active)
   {
      Print("No active setup to confirm.");
      return;
   }

   double bid = 0.0, ask = 0.0;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   bid = tick.bid;
   ask = tick.ask;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double entry = NormalizeDouble(g_entry_price, digits);
   double sl    = NormalizeDouble(g_sl_price, digits);
   double tp    = NormalizeDouble(g_tp_price, digits);

   if(g_setup_direction == 1)
   {
      if(sl >= entry) { Print("ERROR: SL must be below Entry for BUY."); return; }
      if(tp <= entry) { Print("ERROR: TP must be above Entry for BUY."); return; }
   }
   else
   {
      if(sl <= entry) { Print("ERROR: SL must be above Entry for SELL."); return; }
      if(tp >= entry) { Print("ERROR: TP must be below Entry for SELL."); return; }
   }

   double tolerance = point * 2.0;
   bool is_pending = false;
   ENUM_ORDER_TYPE order_type;
   double price = 0.0;
   string mode_text = "";

   if(g_setup_direction == 1)
   {
      if(entry < ask - tolerance)         { order_type = ORDER_TYPE_BUY_LIMIT;  price = entry; mode_text = "BUY LIMIT";  is_pending = true; }
      else if(entry > ask + tolerance)    { order_type = ORDER_TYPE_BUY_STOP;  price = entry; mode_text = "BUY STOP";   is_pending = true; }
      else                                { order_type = ORDER_TYPE_BUY;       price = ask;   mode_text = "BUY MARKET"; }
   }
   else
   {
      if(entry > bid + tolerance)         { order_type = ORDER_TYPE_SELL_LIMIT; price = entry; mode_text = "SELL LIMIT"; is_pending = true; }
      else if(entry < bid - tolerance)    { order_type = ORDER_TYPE_SELL_STOP; price = entry; mode_text = "SELL STOP";  is_pending = true; }
      else                                { order_type = ORDER_TYPE_SELL;      price = bid;   mode_text = "SELL MARKET"; }
   }

   bool result = false;

   if(is_pending)
   {
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action    = TRADE_ACTION_PENDING;
      req.symbol    = _Symbol;
      req.volume    = currentLot;
      req.price     = price;
      req.sl        = sl;
      req.tp        = tp;
      req.type      = order_type;
      req.type_time = ORDER_TIME_GTC;
      req.comment   = "Pro Panel";
      result = OrderSend(req, res);
   }
   else
   {
      result = trade.PositionOpen(_Symbol, order_type, currentLot, price, sl, tp, "Pro Panel");
   }

   if(result)
   {
      Print("✅ " + mode_text + " placed successfully!");
      // ذخیره ستاپ تایید شده برای ماندگاری روی چارت
      int cnt = g_confirmed_cnt;
      if(GlobalVariableCheck("ProPanel_ConfCount"))
         cnt = (int)GlobalVariableGet("ProPanel_ConfCount");
      SaveConfirmedSetup(cnt, g_setup_direction, g_entry_price, g_sl_price, g_tp_price);
      cnt++;
      GlobalVariableSet("ProPanel_ConfCount", cnt);
      g_confirmed_cnt = cnt;

      // باکس‌ها روی چارت ثابت می‌مونن (غیرقابل انتخاب)
      string setup_names[] = {"entry_line","sl_line","tp_line","profit_zone","loss_zone","entry_label","sl_label","tp_label","rr_label"};
      for(int i = 0; i < ArraySize(setup_names); i++)
      {
         string name = ObjName(setup_names[i]);
         if(ObjectFind(0, name) != -1)
         {
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
      }
      // فقط وضعیت رو غیرفعال می‌کنیم و دکمه‌ها رو ریست می‌کنیم
      g_setup_active = false;
      g_setup_direction = 0;
      ObjectSetInteger(0, prefix + "BtnBuy", OBJPROP_BGCOLOR, btnBuyColor);
      ObjectSetString(0, prefix + "BtnBuy", OBJPROP_TEXT, "BUY ▲");
      ObjectSetInteger(0, prefix + "BtnSell", OBJPROP_BGCOLOR, btnSellColor);
      ObjectSetString(0, prefix + "BtnSell", OBJPROP_TEXT, "SELL ▼");
      ObjectSetString(0, prefix + "OrderMode", OBJPROP_TEXT, "");
      ObjectSetInteger(0, prefix + "BtnConfirm", OBJPROP_BGCOLOR, btnConfirmColor);
      ObjectSetString(0, prefix + "BtnConfirm", OBJPROP_TEXT, "✅ Confirm");
   }
   else
   {
      string err = "❌ " + mode_text + " failed! Error: " + IntegerToString(GetLastError());
      Print(err);
      ObjectSetString(0, prefix + "BtnConfirm", OBJPROP_TEXT, "❌ Failed!");
      ObjectSetInteger(0, prefix + "BtnConfirm", OBJPROP_BGCOLOR, btnSellColor);
      return;
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   currentLot = DefaultLot;
   currentTP  = DefaultTP;
   currentSL  = DefaultSL;
   trailingState = UseTrailing;
   g_trailStop = TrailingStop;
   g_bePips    = BreakEvenPips;

   if(GlobalVariableCheck("ProPanel_Minimized"))
      g_panel_minimized = (int)GlobalVariableGet("ProPanel_Minimized") == 1;

   CreatePanelUI();

   // بازیابی Setup از GlobalVariable (برای تغییر تایم فریم)
   if(GlobalVariableCheck("ProPanel_SetupActive") && (int)GlobalVariableGet("ProPanel_SetupActive") == 1)
   {
      g_setup_active    = true;
      g_setup_direction = (int)GlobalVariableGet("ProPanel_Direction");
      g_entry_price     = GlobalVariableGet("ProPanel_Entry");
      g_sl_price        = GlobalVariableGet("ProPanel_SL");
      g_tp_price        = GlobalVariableGet("ProPanel_TP");
      currentLot        = GlobalVariableGet("ProPanel_Lot");
      currentSL         = (int)GlobalVariableGet("ProPanel_SLpts");
      currentTP         = (int)GlobalVariableGet("ProPanel_TPpts");

      g_cached_entry = g_entry_price;
      g_cached_sl    = g_sl_price;
      g_cached_tp    = g_tp_price;

      UpdateSetupVisuals();
      ObjectSetString(0, prefix + "BtnBuy", OBJPROP_TEXT, (g_setup_direction == 1) ? "BUY PENDING" : "BUY ▲");
      ObjectSetString(0, prefix + "BtnSell", OBJPROP_TEXT, (g_setup_direction == 1) ? "SELL ▼" : "SELL PENDING");
      if(g_setup_direction == 1)
         ObjectSetInteger(0, prefix + "BtnBuy", OBJPROP_BGCOLOR, C'60,179,113');
      else
         ObjectSetInteger(0, prefix + "BtnSell", OBJPROP_BGCOLOR, C'220,20,60');

      string mode = DetectOrderMode(g_entry_price);
      ObjectSetString(0, prefix + "OrderMode", OBJPROP_TEXT, mode);
      UpdateUIValues();
   }

   // بازیابی ستاپ‌های تایید شده قبلی
   RestoreConfirmedSetups();

   ChartRedraw();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // ذخیره وضعیت Setup قبل از پاک شدن (برای تغییر تایم فریم)
   if(reason == REASON_CHARTCHANGE)
   {
      if(g_setup_active)
      {
         GlobalVariableSet("ProPanel_SetupActive", 1);
         GlobalVariableSet("ProPanel_Direction", g_setup_direction);
         GlobalVariableSet("ProPanel_Entry", g_entry_price);
         GlobalVariableSet("ProPanel_SL", g_sl_price);
         GlobalVariableSet("ProPanel_TP", g_tp_price);
         GlobalVariableSet("ProPanel_Lot", currentLot);
         GlobalVariableSet("ProPanel_SLpts", currentSL);
         GlobalVariableSet("ProPanel_TPpts", currentTP);
         GlobalVariableSet("ProPanel_Minimized", g_panel_minimized ? 1 : 0);
      }
      else
      {
         GlobalVariableSet("ProPanel_SetupActive", 0);
      }
   }

   ObjectsDeleteAll(0, prefix);
   DeleteSetupObjects();

   // فقط وقتی EA حذف میشه (نه تغییر تایم‌فریم) confirmed objects رو پاک کن
   if(reason != REASON_CHARTCHANGE)
   {
      for(int i = 0; i < 100; i++)
      {
         if(ObjectFind(0, "Conf_Entry_" + IntegerToString(i)) != -1) ObjectDelete(0, "Conf_Entry_" + IntegerToString(i));
         if(ObjectFind(0, "Conf_SL_" + IntegerToString(i)) != -1) ObjectDelete(0, "Conf_SL_" + IntegerToString(i));
         if(ObjectFind(0, "Conf_TP_" + IntegerToString(i)) != -1) ObjectDelete(0, "Conf_TP_" + IntegerToString(i));
         if(ObjectFind(0, "Conf_Profit_" + IntegerToString(i)) != -1) ObjectDelete(0, "Conf_Profit_" + IntegerToString(i));
         if(ObjectFind(0, "Conf_Loss_" + IntegerToString(i)) != -1) ObjectDelete(0, "Conf_Loss_" + IntegerToString(i));
      }
   }

   EventKillTimer();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateLiveStats();
}

//+------------------------------------------------------------------+
//| Timer Event                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateLiveStats();
   if(trailingState) ApplyTrailingStop();
   if(breakEvenState) ApplyBreakEven();
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // ===== مدیریت درگ خطوط Setup روی چارت =====
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      if(sparam == ObjName("entry_line"))
      {
         if(g_setup_active && g_cached_entry != 0.0)
         {
            double new_entry = ObjectGetDouble(0, ObjName("entry_line"), OBJPROP_PRICE, 0);
            double delta = new_entry - g_cached_entry;

            if(MathAbs(delta) > 0.0)
            {
               double new_sl = g_cached_sl + delta;
               double new_tp = g_cached_tp + delta;

               g_entry_price = new_entry;
               g_sl_price    = new_sl;
               g_tp_price    = new_tp;
            }
         }
         if(g_setup_active)
         {
            string mode = DetectOrderMode(g_entry_price);
            ObjectSetString(0, prefix + "OrderMode", OBJPROP_TEXT, mode);
         }
         UpdateSetupVisuals();
         return;
      }

      if(sparam == ObjName("sl_line"))
      {
         if(g_setup_active)
         {
            g_sl_price = ObjectGetDouble(0, ObjName("sl_line"), OBJPROP_PRICE, 0);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            if(point > 0.0)
            {
               int newSL = (int)MathRound(MathAbs(g_entry_price - g_sl_price) / point);
               if(newSL > 0) { currentSL = newSL; UpdateUIValues(); }
            }
         }
         UpdateSetupVisuals();
         return;
      }

      if(sparam == ObjName("tp_line"))
      {
         if(g_setup_active)
         {
            g_tp_price = ObjectGetDouble(0, ObjName("tp_line"), OBJPROP_PRICE, 0);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            if(point > 0.0)
            {
               int newTP = (int)MathRound(MathAbs(g_entry_price - g_tp_price) / point);
               if(newTP > 0) { currentTP = newTP; UpdateUIValues(); }
            }
         }
         UpdateSetupVisuals();
         return;
      }
   }

   // ===== ویرایش دستی فیلدهای SL و TP =====
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == prefix + "ValSL")
      {
         string text = ObjectGetString(0, prefix + "ValSL", OBJPROP_TEXT);
         int val = (int)StringToInteger(text);
         if(val > 0) { currentSL = val; UpdateUIValues(); if(g_setup_active) UpdateSetupFromPanel(); }
         return;
      }
      if(sparam == prefix + "ValTP")
      {
         string text = ObjectGetString(0, prefix + "ValTP", OBJPROP_TEXT);
         int val = (int)StringToInteger(text);
         if(val > 0) { currentTP = val; UpdateUIValues(); if(g_setup_active) UpdateSetupFromPanel(); }
         return;
      }
   }

   // ===== مدیریت کلیک روی اشیاء =====
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(StringFind(sparam, prefix) != 0)
      return;

   // --- Minimize (همیشه فعال) ---
   if(sparam == prefix + "BtnMinimize")
   {
      g_panel_minimized = !g_panel_minimized;
      CreatePanelUI();
      ChartRedraw();
      return;
   }

   // --- Buy Zone / Sell Zone (همیشه فعال) ---
   if(sparam == prefix + "BtnBuyZone")
   {
      CreateZone(1);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
      return;
   }
   if(sparam == prefix + "BtnSellZone")
   {
      CreateZone(-1);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
      return;
   }

   // --- BUY ---
   if(sparam == prefix + "BtnBuy")
   {
      if(!g_setup_active)
         CreateGraphicalSetup(1);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
      return;
   }

   // --- SELL ---
   if(sparam == prefix + "BtnSell")
   {
      if(!g_setup_active)
         CreateGraphicalSetup(-1);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
      return;
   }

   // --- Confirm ---
   if(sparam == prefix + "BtnConfirm")
   {
      ConfirmSetupOrder();
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
      return;
   }

   // --- Cancel (فقط باکس فعال رو مخفی می‌کنه، confirmed رو حذف نمی‌کنه) ---
   if(sparam == prefix + "BtnCancel")
   {
      if(g_setup_active)
      {
         DeleteSetupObjects();
         g_setup_active = false;
         g_setup_direction = 0;
      }
      ObjectSetString(0, prefix + "OrderMode", OBJPROP_TEXT, "");
      ObjectSetInteger(0, prefix + "BtnConfirm", OBJPROP_BGCOLOR, btnConfirmColor);
      ObjectSetString(0, prefix + "BtnConfirm", OBJPROP_TEXT, "✅ Confirm");
      ObjectSetInteger(0, prefix + "BtnBuy", OBJPROP_BGCOLOR, btnBuyColor);
      ObjectSetString(0, prefix + "BtnBuy", OBJPROP_TEXT, "BUY ▲");
      ObjectSetInteger(0, prefix + "BtnSell", OBJPROP_BGCOLOR, btnSellColor);
      ObjectSetString(0, prefix + "BtnSell", OBJPROP_TEXT, "SELL ▼");
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
      return;
   }

   // --- دکمه‌هایی که همیشه فعال باشن (حتی با Setup فعال) ---
   if(g_setup_active)
   {
      bool handled = true;

      if(sparam == prefix + "BtnLotPlus")        ModifyLot(true);
      else if(sparam == prefix + "BtnLotMinus")   ModifyLot(false);
      else if(sparam == prefix + "BtnSLPlus")     { currentSL += 10; UpdateUIValues(); UpdateSetupFromPanel(); }
      else if(sparam == prefix + "BtnSLMinus")    { currentSL = MathMax(0, currentSL - 10); UpdateUIValues(); UpdateSetupFromPanel(); }
      else if(sparam == prefix + "BtnTPPlus")     { currentTP += 10; UpdateUIValues(); UpdateSetupFromPanel(); }
      else if(sparam == prefix + "BtnTPMinus")    { currentTP = MathMax(0, currentTP - 10); UpdateUIValues(); UpdateSetupFromPanel(); }
      else if(sparam == prefix + "BtnTrail")      { trailingState = !trailingState; ObjectSetInteger(0, prefix + "BtnTrail", OBJPROP_BGCOLOR, trailingState ? btnBuyColor : btnNormalColor); }
      else if(sparam == prefix + "BtnBE")         { breakEvenState = !breakEvenState; ObjectSetInteger(0, prefix + "BtnBE", OBJPROP_BGCOLOR, breakEvenState ? btnBuyColor : btnNormalColor); }
      else if(sparam == prefix + "BtnTrailPlus")  { g_trailStop = MathMin(500, g_trailStop + 5); UpdateTrailBEValues(); }
      else if(sparam == prefix + "BtnTrailMinus") { g_trailStop = MathMax(5, g_trailStop - 5); UpdateTrailBEValues(); }
      else if(sparam == prefix + "BtnBEPlus")     { g_bePips = MathMin(500, g_bePips + 5); UpdateTrailBEValues(); }
      else if(sparam == prefix + "BtnBEMinus")    { g_bePips = MathMax(5, g_bePips - 5); UpdateTrailBEValues(); }
      else if(sparam == prefix + "BtnBuyZone")    { CreateZone(1); }
      else if(sparam == prefix + "BtnSellZone")   { CreateZone(-1); }
      else if(sparam == prefix + "BtnCloseAll")   CloseAll(0);
      else if(sparam == prefix + "BtnCloseBuy")   CloseAll(1);
      else if(sparam == prefix + "BtnCloseSell")  CloseAll(2);
      else if(sparam == prefix + "BtnCloseProfit") CloseByProfit(true);
      else
         handled = false;

      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      if(handled) ChartRedraw();
      return;
   }

   // --- دکمه‌های عادی (وقتی Setup فعال نیست) ---
   if(sparam == prefix + "BtnLotPlus")      ModifyLot(true);
   else if(sparam == prefix + "BtnLotMinus") ModifyLot(false);
   else if(sparam == prefix + "BtnSLPlus")  { currentSL += 10; UpdateUIValues(); }
   else if(sparam == prefix + "BtnSLMinus") { currentSL = MathMax(0, currentSL - 10); UpdateUIValues(); }
   else if(sparam == prefix + "BtnTPPlus")  { currentTP += 10; UpdateUIValues(); }
   else if(sparam == prefix + "BtnTPMinus") { currentTP = MathMax(0, currentTP - 10); UpdateUIValues(); }
   else if(sparam == prefix + "BtnTrail")   { trailingState = !trailingState; ObjectSetInteger(0, prefix + "BtnTrail", OBJPROP_BGCOLOR, trailingState ? btnBuyColor : btnNormalColor); }
   else if(sparam == prefix + "BtnBE")      { breakEvenState = !breakEvenState; ObjectSetInteger(0, prefix + "BtnBE", OBJPROP_BGCOLOR, breakEvenState ? btnBuyColor : btnNormalColor); }
   else if(sparam == prefix + "BtnTrailPlus")   { g_trailStop = MathMin(500, g_trailStop + 5); UpdateTrailBEValues(); }
   else if(sparam == prefix + "BtnTrailMinus")  { g_trailStop = MathMax(5, g_trailStop - 5); UpdateTrailBEValues(); }
   else if(sparam == prefix + "BtnBEPlus")      { g_bePips = MathMin(500, g_bePips + 5); UpdateTrailBEValues(); }
   else if(sparam == prefix + "BtnBEMinus")     { g_bePips = MathMax(5, g_bePips - 5); UpdateTrailBEValues(); }
   else if(sparam == prefix + "BtnBuyZone")    CreateZone(1);
   else if(sparam == prefix + "BtnSellZone")   CreateZone(-1);
   else if(sparam == prefix + "BtnCloseAll")   CloseAll(0);
   else if(sparam == prefix + "BtnCloseBuy")   CloseAll(1);
   else if(sparam == prefix + "BtnCloseSell")  CloseAll(2);
   else if(sparam == prefix + "BtnCloseProfit") CloseByProfit(true);

   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ساخت المان‌های رابط کاربری پنل                                   |
//+------------------------------------------------------------------+
void CreatePanelUI()
{
   // پاک کردن کامل آبجکت‌های قدیمی پنل قبل از بازسازی (مهم برای minimize)
   ObjectsDeleteAll(0, prefix);

   // در حالت minimized فقط هدر + علامت نمایش داده بشه
   if(g_panel_minimized)
   {
      int y = panelY;
      CreateRect(prefix + "BG", panelX, y, 200, 40, bgMain);
      CreateRect(prefix + "Header", panelX, y, 200, 40, bgHeader);
      CreateText(prefix + "Title", panelX + 15, y + 12, "PRO PANEL", textWhite, 10, "Arial Bold");
      CreateButton(prefix + "BtnMinimize", panelX + 170, y + 9, 22, 22, "⬜", btnNormalColor, textWhite, 8);
      return;
   }

   int y = panelY;

   CreateRect(prefix + "BG", panelX, y, panelWidth, panelHeight, bgMain);
   CreateRect(prefix + "Header", panelX, y, panelWidth, 40, bgHeader);
   CreateText(prefix + "Title", panelX + 15, y + 12, "PRO TRADING PANEL", textWhite, 10, "Arial Bold");
   CreateText(prefix + "Ver", panelX + 210, y + 14, "v3.10", textGray, 7, "Arial");
   CreateButton(prefix + "BtnMinimize", panelX + 240, y + 9, 22, 22, "−", btnNormalColor, textWhite, 10);
   y += 50;

   // Buy & Sell
   CreateButton(prefix + "BtnBuy", panelX + 15, y, 115, 40, "BUY ▲", btnBuyColor, textWhite, 11);
   CreateButton(prefix + "BtnSell", panelX + 140, y, 115, 40, "SELL ▼", btnSellColor, textWhite, 11);
   y += 48;

   // Buy Zone & Sell Zone - زیر دکمه‌های Buy/Sell
   CreateButton(prefix + "BtnBuyZone", panelX + 15, y, 115, 22, "Buy Zone", C'40,130,80', textWhite, 7);
   CreateButton(prefix + "BtnSellZone", panelX + 140, y, 115, 22, "Sell Zone", C'150,30,30', textWhite, 7);
   y += 28;

   // Confirm / Cancel + Order Mode
   CreateButton(prefix + "BtnConfirm", panelX + 15, y, 115, 30, "✅ Confirm", btnConfirmColor, textWhite, 9);
   CreateButton(prefix + "BtnCancel", panelX + 140, y, 115, 30, "❌ Cancel", C'100,30,40', textWhite, 9);
   CreateText(prefix + "OrderMode", panelX + 95, y + 33, "", textGold, 8, "Arial Bold");
   y += 45;

   // Lot
   CreateText(prefix + "LblLot", panelX + 15, y + 5, "VOLUME LOT:", textGray, 8, "Arial Bold");
   CreateButton(prefix + "BtnLotMinus", panelX + 120, y, 30, 25, "−", btnNormalColor, textWhite, 10);
   CreateButton(prefix + "BtnLotPlus", panelX + 225, y, 30, 25, "+", btnNormalColor, textWhite, 10);
   CreateRect(prefix + "LotBg", panelX + 155, y, 65, 25, bgHeader);
   CreateText(prefix + "ValLot", panelX + 172, y + 6, DoubleToString(currentLot, 2), textGold, 9, "Consolas Bold");
   y += 35;

   // SL / TP
   CreateText(prefix + "LblSL", panelX + 55, y, "SL", textGray, 8, "Arial Bold");
   CreateText(prefix + "LblTP", panelX + 180, y, "TP", textGray, 8, "Arial Bold");
   y += 18;

   CreateButton(prefix + "BtnSLMinus", panelX + 15, y, 20, 22, "−", btnNormalColor, textWhite, 10);
   CreateRect(prefix + "SLBg", panelX + 38, y, 48, 22, C'80,25,25');
   CreateEdit(prefix + "ValSL", panelX + 39, y + 1, 46, 20, IntegerToString(currentSL), C'80,25,25');
   CreateButton(prefix + "BtnSLPlus", panelX + 89, y, 20, 22, "+", btnNormalColor, textWhite, 10);

   CreateButton(prefix + "BtnTPMinus", panelX + 143, y, 20, 22, "−", btnNormalColor, textWhite, 10);
   CreateRect(prefix + "TPBg", panelX + 166, y, 48, 22, C'30,110,60');
   CreateEdit(prefix + "ValTP", panelX + 167, y + 1, 46, 20, IntegerToString(currentTP), C'30,110,60');
   CreateButton(prefix + "BtnTPPlus", panelX + 217, y, 20, 22, "+", btnNormalColor, textWhite, 10);
   y += 32;

   // Trailing / BE - زیر SL/TP
   CreateButton(prefix + "BtnTrail", panelX + 15, y, 115, 25, "Trailing Stop", trailingState ? btnBuyColor : btnNormalColor, textWhite, 8);
   CreateButton(prefix + "BtnBE", panelX + 140, y, 115, 25, "Break Even", breakEvenState ? btnBuyColor : btnNormalColor, textWhite, 8);
   y += 28;

   // Trail/BE adjust
   CreateButton(prefix + "BtnTrailMinus", panelX + 15, y, 20, 20, "−", btnNormalColor, textWhite, 8);
   CreateRect(prefix + "TrailValBg", panelX + 38, y, 55, 20, bgHeader);
   CreateText(prefix + "ValTrail", panelX + 60, y + 3, IntegerToString(g_trailStop), textWhite, 8, "Consolas Bold");
   CreateButton(prefix + "BtnTrailPlus", panelX + 96, y, 20, 20, "+", btnNormalColor, textWhite, 8);

   CreateButton(prefix + "BtnBEMinus", panelX + 145, y, 20, 20, "−", btnNormalColor, textWhite, 8);
   CreateRect(prefix + "BEValBg", panelX + 168, y, 48, 20, bgHeader);
   CreateText(prefix + "ValBE", panelX + 187, y + 3, IntegerToString(g_bePips), textWhite, 8, "Consolas Bold");
   CreateButton(prefix + "BtnBEPlus", panelX + 219, y, 20, 20, "+", btnNormalColor, textWhite, 8);
   y += 25;

   // Separator
   CreateRect(prefix + "Line", panelX + 15, y, panelWidth - 30, 1, borderLine);
   y += 10;

   // Stats
   CreateText(prefix + "StatBuy", panelX + 20, y, "Buy: 0 (0.00 Lot)", textGray, 8);
   CreateText(prefix + "StatBuyPL", panelX + 180, y, "$ 0.00", textWhite, 8, "Consolas Bold");
   y += 18;

   CreateText(prefix + "StatSell", panelX + 20, y, "Sell: 0 (0.00 Lot)", textGray, 8);
   CreateText(prefix + "StatSellPL", panelX + 180, y, "$ 0.00", textWhite, 8, "Consolas Bold");
   y += 18;

   CreateText(prefix + "StatTotal", panelX + 20, y, "Total Profit:", textGold, 9, "Arial Bold");
   CreateText(prefix + "StatTotalPL", panelX + 180, y, "$ 0.00", textGold, 10, "Consolas Bold");
   y += 30;

   // Close buttons
   CreateButton(prefix + "BtnCloseBuy", panelX + 15, y, 75, 25, "Close Buy", btnNormalColor, textWhite, 8);
   CreateButton(prefix + "BtnCloseSell", panelX + 95, y, 75, 25, "Close Sell", btnNormalColor, textWhite, 8);
   CreateButton(prefix + "BtnCloseProfit", panelX + 175, y, 80, 25, "Close Profit", btnNormalColor, textWhite, 8);
   y += 30;

   CreateButton(prefix + "BtnCloseAll", panelX + 15, y, 240, 30, "PANIC CLOSE ALL", btnSellColor, textWhite, 9);
}

//+------------------------------------------------------------------+
//| توابع کمکی                                                       |
//+------------------------------------------------------------------+
void CreateRect(string name, int x, int y, int w, int h, color clr)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C'70,80,100');
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color fg, int fSize)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'100,110,130');
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateEdit(string name, int x, int y, int w, int h, string text, color bg=C'30,30,40')
{
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_SUNKEN);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'80,85,100');
   ObjectSetInteger(0, name, OBJPROP_COLOR, textWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas Bold");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateText(string name, int x, int y, string text, color clr, int fSize, string font="Arial")
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| اصلاح مقادیر                                                     |
//+------------------------------------------------------------------+
void ModifyLot(bool increase)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(increase)
      currentLot = MathMin(maxLot, currentLot + LotStep);
   else
      currentLot = MathMax(minLot, currentLot - LotStep);
   UpdateUIValues();
   if(g_setup_active) UpdateSetupVisuals();
}

void UpdateUIValues()
{
   ObjectSetString(0, prefix + "ValLot", OBJPROP_TEXT, DoubleToString(currentLot, 2));
   ObjectSetString(0, prefix + "ValSL", OBJPROP_TEXT, IntegerToString(currentSL));
   ObjectSetString(0, prefix + "ValTP", OBJPROP_TEXT, IntegerToString(currentTP));
}

void UpdateTrailBEValues()
{
   ObjectSetString(0, prefix + "ValTrail", OBJPROP_TEXT, IntegerToString(g_trailStop));
   ObjectSetString(0, prefix + "ValBE", OBJPROP_TEXT, IntegerToString(g_bePips));
}

string DetectOrderMode(const double entry)
{
   double bid = 0.0, ask = 0.0;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return "";
   bid = tick.bid; ask = tick.ask;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return "";
   double tolerance = point * 2.0;

   if(g_setup_direction == 1)
   {
      if(entry < ask - tolerance) return "↘ BUY LIMIT";
      if(entry > ask + tolerance) return "↗ BUY STOP";
      return "► BUY MARKET";
   }
   else if(g_setup_direction == -1)
   {
      if(entry > bid + tolerance) return "↗ SELL LIMIT";
      if(entry < bid - tolerance) return "↘ SELL STOP";
      return "► SELL MARKET";
   }
   return "";
}

//+------------------------------------------------------------------+
//| آمار زنده                                                        |
//+------------------------------------------------------------------+
void UpdateLiveStats()
{
   int buyCount = 0, sellCount = 0;
   double buyVol = 0, sellVol = 0;
   double buyPL = 0, sellPL = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         { buyCount++; buyVol += volume; buyPL += profit; }
      else
         { sellCount++; sellVol += volume; sellPL += profit; }
   }

   double totalPL = buyPL + sellPL;

   ObjectSetString(0, prefix + "StatBuy", OBJPROP_TEXT, "Buy: " + IntegerToString(buyCount) + " (" + DoubleToString(buyVol, 2) + " Lot)");
   ObjectSetString(0, prefix + "StatBuyPL", OBJPROP_TEXT, "$ " + DoubleToString(buyPL, 2));
   ObjectSetInteger(0, prefix + "StatBuyPL", OBJPROP_COLOR, buyPL >= 0 ? btnBuyColor : btnSellColor);
   ObjectSetString(0, prefix + "StatSell", OBJPROP_TEXT, "Sell: " + IntegerToString(sellCount) + " (" + DoubleToString(sellVol, 2) + " Lot)");
   ObjectSetString(0, prefix + "StatSellPL", OBJPROP_TEXT, "$ " + DoubleToString(sellPL, 2));
   ObjectSetInteger(0, prefix + "StatSellPL", OBJPROP_COLOR, sellPL >= 0 ? btnBuyColor : btnSellColor);
   ObjectSetString(0, prefix + "StatTotalPL", OBJPROP_TEXT, "$ " + DoubleToString(totalPL, 2));
   ObjectSetInteger(0, prefix + "StatTotalPL", OBJPROP_COLOR, totalPL >= 0 ? btnBuyColor : btnSellColor);
}

//+------------------------------------------------------------------+
//| مدیریت پوزیشن‌ها                                                   |
//+------------------------------------------------------------------+
void CloseAll(int filter)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(filter == 0) trade.PositionClose(ticket);
      else if(filter == 1 && type == POSITION_TYPE_BUY) trade.PositionClose(ticket);
      else if(filter == 2 && type == POSITION_TYPE_SELL) trade.PositionClose(ticket);
   }
}

void CloseByProfit(bool onlyProfitable)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(onlyProfitable && profit > 0) trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| الگوریتم‌های مدیریت ریسک                                          |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = NormalizeDouble(bid - g_trailStop * point, digits);
         if(newSL > sl && newSL < bid) trade.PositionModify(ticket, newSL, tp);
      }
      else
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = NormalizeDouble(ask + g_trailStop * point, digits);
         if((newSL < sl || sl == 0) && newSL > ask) trade.PositionModify(ticket, newSL, tp);
      }
   }
}

void ApplyBreakEven()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid >= openPrice + g_bePips * point && sl < openPrice)
            trade.PositionModify(ticket, openPrice, tp);
      }
      else
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= openPrice - g_bePips * point && (sl > openPrice || sl == 0))
            trade.PositionModify(ticket, openPrice, tp);
      }
   }
}
//+------------------------------------------------------------------+
