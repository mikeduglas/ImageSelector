!* Image selector
!* mikeduglas@yandex.ru
!* 2022

  MEMBER


  INCLUDE('imgsel.inc'), ONCE

  MAP
    INCLUDE('printf.inc'), ONCE

    MODULE('win api')
      winapi::GetSysColor(LONG nIndex),UNSIGNED,PASCAL,PROC,NAME('GetSysColor')
    END

    LOWORD(LONG pLongVal), LONG, PRIVATE
    HIWORD(LONG pLongVal), LONG, PRIVATE
    GET_X_LPARAM(LONG pLongVal), SHORT, PRIVATE
    GET_Y_LPARAM(LONG pLongVal), SHORT, PRIVATE
  
    img_SubclassProc(HWND hWnd, ULONG wMsg, UNSIGNED wParam, LONG lParam, ULONG subclassId, UNSIGNED dwRefData), LONG, PASCAL, PRIVATE
  END


WM_MOUSEWHEEL                 EQUATE(020Ah)
COLOR:WINDOWGRAY              EQUATE(0F0F0F0H)    !- default TAB background 


!!!region macros
LOWORD                        PROCEDURE(LONG pLongVal)
  CODE
  RETURN BAND(pLongVal, 0FFFFh)

HIWORD                        PROCEDURE(LONG pLongVal)
  CODE
  RETURN BSHIFT(BAND(pLongVal, 0FFFF0000h), -16)

GET_X_LPARAM                  PROCEDURE(LONG pLongVal)
  CODE
  RETURN LOWORD(pLongVal)

GET_Y_LPARAM                  PROCEDURE(LONG pLongVal)
  CODE
  RETURN HIWORD(pLongVal)
!!!endregion
  
!!!region callbacks
img_SubclassProc              PROCEDURE(HWND hWnd, ULONG wMsg, UNSIGNED wParam, LONG lParam, ULONG subclassId, UNSIGNED dwRefData)
win                             TWnd
ctrl                            &TBaseImageSelector
  CODE
  win.SetHandle(hWnd)
  !- get TBaseImageSelector instance
  ctrl &= (dwRefData)
  IF ctrl &= NULL
    !- not our window
    RETURN win.DefSubclassProc(wMsg, wParam, lParam)
  END

  CASE wMsg
  OF WM_PAINT
    ctrl.OnPaint()
    RETURN FALSE
  OF WM_VSCROLL
    !https://stackoverflow.com/questions/32094254/how-to-control-scrollbar-in-vc-win32-api
    IF ctrl.OnVScroll(wParam, lParam) = FALSE
      RETURN FALSE
    END
  OF WM_HSCROLL
    IF ctrl.OnHScroll(wParam, lParam) = FALSE
      RETURN FALSE
    END
  OF WM_MOUSEWHEEL
    !- mouse wheel
    IF ctrl.OnMouseWheel(wParam) = FALSE
      RETURN FALSE
    END
  OF WM_LBUTTONDOWN
    IF ctrl.OnLButtonDown(wParam, lParam) = FALSE
      RETURN FALSE
    END
  END
  
  !- call original window proc
  RETURN ctrl.DefSubclassProc(wMsg, wParam, lParam)
!!!endregion
  
!!!region TBaseImageSelector
TBaseImageSelector.Construct  PROCEDURE()
  CODE
  SELF.frameOutline.cx = 10
  SELF.frameOutline.cy = 10
  SELF.bkColor = COLOR:White
  SELF.selColor = COLOR:Red
  SELF.selPenWidth = 3
  SELF.currentFrame = 0
  
TBaseImageSelector.Destruct   PROCEDURE()
  CODE
  SELF.Kill()
  
TBaseImageSelector.Init       PROCEDURE(SIGNED pFeq)
  CODE
  ASSERT(pFeq{PROP:Type} = CREATE:image)
  IF pFeq{PROP:Type} = CREATE:image
    PARENT.Init(pFeq)
    SELF.SetWindowSubclass(ADDRESS(img_SubclassProc), 0, ADDRESS(SELF))
    SELF.PrepareControl()
  ELSE
    printd('TImageSelector.Init(%i) error: Invalid control type', pFeq)
  END
  
TBaseImageSelector.Kill       PROCEDURE()
  CODE
  IF NOT SELF.framesData &= NULL
    FREE(SELF.framesData)
    DISPOSE(SELF.framesData)
    SELF.framesData &= NULL
  END
  
  IF NOT SELF.framesImage &= NULL
    DISPOSE(SELF.framesImage)
    SELF.framesImage &= NULL
  END
  
TBaseImageSelector.AddFile    PROCEDURE(STRING pFileName, <STRING pDescr>)
df                              TDiskFile
sData                           &STRING
  CODE
  sData &= df.LoadFile(pFileName)
  IF NOT sData &= NULL
    SELF.AddRawData(sData)
    DISPOSE(sData)
  END
  
TBaseImageSelector.AddRawData PROCEDURE(CONST *STRING pRawData, <STRING pDescr>)
  CODE
  IF SELF.framesData &= NULL
    SELF.framesData &= NEW typImgSelFramesData
  END
  
  CLEAR(SELF.framesData)
  SELF.framesData.Descr = pDescr
  SELF.framesData.ImageData = CLIP(pRawData)
  ADD(SELF.framesData)
  
TBaseImageSelector.SelectFrame    PROCEDURE(UNSIGNED pFrameIndex)
  CODE
  
TBaseImageSelector.SetBackColor   PROCEDURE(LONG pBackColor)
  CODE
  IF pBackColor <> COLOR:NONE
    SELF.bkColor = pBackColor
  ELSE
    SELF.bkColor = COLOR:WINDOWGRAY
  END
  
TBaseImageSelector.SetSelColor    PROCEDURE(LONG pSelColor)
  CODE
  SELF.selColor = pSelColor
  
TBaseImageSelector.SetSelPenWidth PROCEDURE(UNSIGNED pPenWidth)
  CODE
  SELF.selPenWidth = pPenWidth
  
TBaseImageSelector.SetOutlineSize PROCEDURE(UNSIGNED pWidth, UNSIGNED pHeight)
  CODE
  SELF.frameOutline.cx = pWidth
  SELF.frameOutline.cy = pHeight

TBaseImageSelector.PrepareControl PROCEDURE()
  CODE
  
TBaseImageSelector.CreateFramesImage  PROCEDURE()
  CODE
  
TBaseImageSelector.RedrawFramesImage  PROCEDURE(TDC dc)
  CODE
  
TBaseImageSelector.OnPaint    PROCEDURE()
dc                              TPaintDC
  CODE
  IF SELF.framesImage &= NULL
    !- first run
    SELF.CreateFramesImage()
  END
  
  dc.GetDC(SELF)
  SELF.RedrawFramesImage(dc)
  
TBaseImageSelector.OnVScroll  PROCEDURE(UNSIGNED wParam, LONG lParam)
  CODE
  RETURN TRUE
    
TBaseImageSelector.OnHScroll  PROCEDURE(UNSIGNED wParam, LONG lParam)
  CODE
  RETURN TRUE

TBaseImageSelector.OnMouseWheel   PROCEDURE(UNSIGNED wParam)
  CODE
  RETURN TRUE

TBaseImageSelector.OnLButtonDown  PROCEDURE(UNSIGNED wParam, LONG lParam)
  CODE
  RETURN TRUE

TBaseImageSelector.OnFrameSelected    PROCEDURE(UNSIGNED pFrameIndex)
  CODE
  
!!!endregion

!!!region TVerticalImageSelector
TVerticalImageSelector.SelectFrame    PROCEDURE(UNSIGNED pFrameIndex)
g                                       TGdiPlusGraphics
pen                                     TGdiPlusPen
selRect                                 LIKE(GpRectF)
  CODE
  IF SELF.currentFrame <> pFrameIndex
    g.FromImage(SELF.framesImage)
      
    !- selection rect
    selRect.x = SELF.frameOutline.cx-SELF.selPenWidth/2
    selRect.y = SELF.frameOutline.cy + (SELF.currentFrame-1)*(SELF.frameSize.cy+SELF.frameOutline.cy) - SELF.selPenWidth/2
    selRect.width = SELF.frameSize.cx+SELF.selPenWidth
    selRect.height = SELF.frameSize.cy+SELF.selPenWidth
  
    !- erase previous selection
    pen.CreatePen(GdipMakeARGB(SELF.bkColor), SELF.selPenWidth)
    g.DrawRectangle(pen, selRect)
    pen.DeletePen()
 
    !- draw new selection
    SELF.currentFrame = pFrameIndex
    IF SELF.currentFrame > 0 AND SELF.currentFrame <= RECORDS(SELF.framesData)
      selRect.y = SELF.frameOutline.cy + (SELF.currentFrame-1)*(SELF.frameSize.cy+SELF.frameOutline.cy) - SELF.selPenWidth/2
    
      pen.CreatePen(GdipMakeARGB(SELF.selColor), SELF.selPenWidth)
      g.DrawRectangle(pen, selRect)
      pen.DeletePen()
    END

    g.DeleteGraphics()
    
    SELF.OnFrameSelected(SELF.currentFrame)
  END
  
TVerticalImageSelector.PrepareControl PROCEDURE()
  CODE
  SELF.FEQ{PROP:VScroll} = TRUE
  SELF.ShowScrollBar(SB_VERT, TRUE)
  
TVerticalImageSelector.CreateFramesImage  PROCEDURE()
nRecs                                       LONG, AUTO
rc                                          TRect
frame                                       TGdiPlusImage
thumbnail                                   TGdiPlusImage
g                                           TGdiPlusGraphics
brush                                       TGdiPlusSolidBrush
x                                           SIGNED, AUTO
y                                           SIGNED, AUTO
i                                           LONG, AUTO
  CODE
  SELF.GetClientRect(rc)
  SELF.frameSize.cx = rc.Width() - SELF.frameOutline.cx * 2
  SELF.frameSize.cy = SELF.frameSize.cx * 2 / 3
  nRecs = RECORDS(SELF.framesData)
  
  !- create image of combined thumbnails
  SELF.framesImage &= NEW TGdiPlusBitmap
  SELF.framesImage.CreateBitmap(SELF.frameSize.cx + SELF.frameOutline.cx * 2, (SELF.frameSize.cy + SELF.frameOutline.cy) * nRecs + SELF.frameOutline.cy, PixelFormat24bppRGB)
  g.FromImage(SELF.framesImage)
  !- erase background
  brush.CreateSolidBrush(GdipMakeARGB(SELF.bkColor))
  g.FillRectangle(brush, 0, 0, SELF.framesImage.GetWidth(), SELF.framesImage.GetHeight())
  brush.DeleteBrush()
  
  !- loop thru all frames
  x = SELF.frameOutline.cx
  y = SELF.frameOutline.cy
  LOOP i=1 TO RECORDS(SELF.framesData)
    GET(SELF.framesData, i)
    !- create full image
    frame.FromString(SELF.framesData.ImageData)
    !- create thumbnail
    frame.GetThumbnailImage(SELF.frameSize.cx, SELF.frameSize.cy, thumbnail)
    !- draw thumbnail in bitmap
    g.DrawImage(thumbnail, x, y, SELF.frameSize.cx, SELF.frameSize.cy)
    !- dispose images
    frame.DisposeImage()
    thumbnail.DisposeImage()
    !- shift down
    y += SELF.frameSize.cy + SELF.frameOutline.cy
  END
  
  SELF.SelectFrame(1)
  
TVerticalImageSelector.RedrawFramesImage  PROCEDURE(TDC dc)
g                                           TGdiPlusGraphics
rc                                          TRect
destRect                                    LIKE(GpRect)
srcRect                                     LIKE(GpRect)
  CODE
  g.FromHDC(dc.GetHandle())
  SELF.GetClientRect(rc)
  
  !- draw visible part of the image
  destRect.x=0
  destRect.y=0
  destRect.width=rc.Width()
  destRect.height=rc.Height()
  
  srcRect.x=0
  srcRect.y=(SELF.framesImage.GetHeight() - rc.Height()) * SELF.scrollPos / 100
  srcRect.width=SELF.framesImage.GetWidth()
  srcRect.height=rc.Height()

  g.DrawImage(SELF.framesImage, destRect, srcRect, UnitPixel)
  
TVerticalImageSelector.OnVScroll  PROCEDURE(UNSIGNED wParam, LONG lParam)
rc                                  TRect
dy                                  UNSIGNED, AUTO
py                                  UNSIGNED, AUTO
action                              USHORT, AUTO
pos                                 SIGNED, AUTO
si                                  LIKE(SCROLLINFO)
dc                                  TDC
  CODE
  SELF.GetClientRect(rc)
  dy = 1                                !- line scroll pos
  py = 100 / RECORDS(SELF.framesData)   !- page scroll pos
  
  !- calc scroll pos
  action = LOWORD(wParam)
  pos = -1
  CASE action 
  OF SB_THUMBPOSITION OROF SB_THUMBTRACK
    pos = HIWORD(wParam)
  OF SB_LINEDOWN
    pos = SELF.scrollPos + dy
  OF SB_LINEUP
    pos = SELF.scrollPos - dy
  OF SB_PAGEDOWN
    pos = SELF.scrollPos + py
  OF SB_PAGEUP
    pos = SELF.scrollPos - py
  END
  
  IF pos = -1
    !- no scroll
    RETURN TRUE
  END
  
  !- get actual scroll pos
  si.cbSize = SIZE(si)
  si.fMask = SIF_POS
  si.nPos = pos
  si.nTrackPos = 0
  SELF.SetScrollInfo(SB_VERT, si, TRUE)
  SELF.GetScrollInfo(SB_VERT, si)
  pos = si.nPos

  !- redraw if scroll pos changed
  IF SELF.scrollPos <> pos
    SELF.scrollPos = pos
    dc.GetDC(SELF)
    SELF.RedrawFramesImage(dc)
    dc.ReleaseDC()
  END
  
  RETURN FALSE

TVerticalImageSelector.OnMouseWheel   PROCEDURE(UNSIGNED wParam)
distance                                SHORT, AUTO
vKey                                    SHORT, AUTO
action                                  USHORT, AUTO
  CODE
  distance = HIWORD(wParam)
  vKey = LOWORD(wParam)

  IF distance
    IF distance > 0
      action = SB_LINEUP
    ELSE
      action = SB_LINEDOWN
    END
    SELF.SendMessage(WM_VSCROLL, action, 0)
    RETURN FALSE
  END
  RETURN TRUE

TVerticalImageSelector.OnLButtonDown  PROCEDURE(UNSIGNED wParam, LONG lParam)
dc                                      TDC
pt                                      LIKE(POINT)
rc                                      TRect
n                                       LONG, AUTO
  CODE
  SELF.GetClientRect(rc)
  
  !- pos on the visible image
  pt.x = GET_X_LPARAM(lParam)
  pt.y = GET_Y_LPARAM(lParam)

  !- pos on the big image
  pt.y += (SELF.framesImage.GetHeight() - rc.Height()) * SELF.scrollPos / 100
  
  !- find selected frame number
  n = (pt.y / (SELF.frameSize.cy + SELF.frameOutline.cy)) + 1
  
  !- check for outline clicked
  IF pt.y > ((n-1)*SELF.frameSize.cy + n*SELF.frameOutline.cy)
    IF SELF.currentFrame <> n
      SELF.SelectFrame(n)
      
      !- redraw the control
      dc.GetDC(SELF)
      SELF.RedrawFramesImage(dc)
      dc.ReleaseDC()
      
      !- don't call default handler DefSubclassProc
      RETURN FALSE
    END
  END
  
  !- call default handler DefSubclassProc
  RETURN TRUE
!!!endregion

!!!region THorizontalImageSelector
THorizontalImageSelector.SelectFrame  PROCEDURE(UNSIGNED pFrameIndex)
g                                       TGdiPlusGraphics
pen                                     TGdiPlusPen
selRect                                 LIKE(GpRectF)
  CODE
  IF SELF.currentFrame <> pFrameIndex
    g.FromImage(SELF.framesImage)
      
    !- selection rect
    selRect.x = SELF.frameOutline.cx + (SELF.currentFrame-1)*(SELF.frameSize.cx+SELF.frameOutline.cx) - SELF.selPenWidth/2
    selRect.y = SELF.frameOutline.cy-SELF.selPenWidth/2
    selRect.width = SELF.frameSize.cx+SELF.selPenWidth
    selRect.height = SELF.frameSize.cy+SELF.selPenWidth
  
    !- erase previous selection
    pen.CreatePen(GdipMakeARGB(SELF.bkColor), SELF.selPenWidth)
    g.DrawRectangle(pen, selRect)
    pen.DeletePen()
 
    !- draw new selection
    SELF.currentFrame = pFrameIndex
    IF SELF.currentFrame > 0 AND SELF.currentFrame <= RECORDS(SELF.framesData)
      selRect.x = SELF.frameOutline.cx + (SELF.currentFrame-1)*(SELF.frameSize.cx+SELF.frameOutline.cx) - SELF.selPenWidth/2
    
      pen.CreatePen(GdipMakeARGB(SELF.selColor), SELF.selPenWidth)
      g.DrawRectangle(pen, selRect)
      pen.DeletePen()
    END

    g.DeleteGraphics()
    
    SELF.OnFrameSelected(SELF.currentFrame)
  END
  
THorizontalImageSelector.PrepareControl   PROCEDURE()
  CODE
  SELF.FEQ{PROP:HScroll} = TRUE
  SELF.ShowScrollBar(SB_HORZ, TRUE)
  
THorizontalImageSelector.CreateFramesImage    PROCEDURE()
nRecs                                           LONG, AUTO
rc                                              TRect
frame                                           TGdiPlusImage
thumbnail                                       TGdiPlusImage
g                                               TGdiPlusGraphics
brush                                           TGdiPlusSolidBrush
x                                               SIGNED, AUTO
y                                               SIGNED, AUTO
i                                               LONG, AUTO
  CODE
  SELF.GetClientRect(rc)
  SELF.frameSize.cy = rc.Height() - SELF.frameOutline.cy * 2
  SELF.frameSize.cx = SELF.frameSize.cy * 3 / 2
  nRecs = RECORDS(SELF.framesData)
  
  !- create image of combined thumbnails
  SELF.framesImage &= NEW TGdiPlusBitmap
  SELF.framesImage.CreateBitmap((SELF.frameSize.cx + SELF.frameOutline.cx) * nRecs + SELF.frameOutline.cx, SELF.frameSize.cy + SELF.frameOutline.cy * 2, PixelFormat24bppRGB)
  g.FromImage(SELF.framesImage)
  !- erase background
  brush.CreateSolidBrush(GdipMakeARGB(SELF.bkColor))
  g.FillRectangle(brush, 0, 0, SELF.framesImage.GetWidth(), SELF.framesImage.GetHeight())
  brush.DeleteBrush()
  
  !- loop thru all frames
  x = SELF.frameOutline.cx
  y = SELF.frameOutline.cy
  LOOP i=1 TO RECORDS(SELF.framesData)
    GET(SELF.framesData, i)
    !- create full image
    frame.FromString(SELF.framesData.ImageData)
    !- create thumbnail
    frame.GetThumbnailImage(SELF.frameSize.cx, SELF.frameSize.cy, thumbnail)
    !- draw thumbnail in bitmap
    g.DrawImage(thumbnail, x, y, SELF.frameSize.cx, SELF.frameSize.cy)
    !- dispose images
    frame.DisposeImage()
    thumbnail.DisposeImage()
    !- shift down
    x += SELF.frameSize.cx + SELF.frameOutline.cx
  END
  
  SELF.SelectFrame(1)
  
THorizontalImageSelector.RedrawFramesImage    PROCEDURE(TDC dc)
g                                               TGdiPlusGraphics
rc                                              TRect
destRect                                        LIKE(GpRect)
srcRect                                         LIKE(GpRect)
  CODE
  g.FromHDC(dc.GetHandle())
  SELF.GetClientRect(rc)
  
  !- draw visible part of the image
  destRect.x=0
  destRect.y=0
  destRect.width=rc.Width()
  destRect.height=rc.Height()

  srcRect.x=(SELF.framesImage.GetWidth() - rc.Width()) * SELF.scrollPos / 100
  srcRect.y=0
  srcRect.width=rc.Width()
  srcRect.height=SELF.framesImage.GetHeight()

  g.DrawImage(SELF.framesImage, destRect, srcRect, UnitPixel)
  
THorizontalImageSelector.OnHScroll    PROCEDURE(UNSIGNED wParam, LONG lParam)
rc                                      TRect
dx                                      UNSIGNED, AUTO
px                                      UNSIGNED, AUTO
action                                  USHORT, AUTO
pos                                     SIGNED, AUTO
si                                      LIKE(SCROLLINFO)
dc                                      TDC
  CODE
  SELF.GetClientRect(rc)
  dx = 1                                !- line scroll pos
  px = 100 / RECORDS(SELF.framesData)   !- page scroll pos
  
  !- calc scroll pos
  action = LOWORD(wParam)
  pos = -1
  CASE action 
  OF SB_THUMBPOSITION OROF SB_THUMBTRACK
    pos = HIWORD(wParam)
  OF SB_LINERIGHT
    pos = SELF.scrollPos + dx
  OF SB_LINELEFT
    pos = SELF.scrollPos - dx
  OF SB_PAGERIGHT
    pos = SELF.scrollPos + px
  OF SB_PAGELEFT
    pos = SELF.scrollPos - px
  END
  
  IF pos = -1
    !- no scroll
    RETURN TRUE
  END
  
  !- get actual scroll pos
  si.cbSize = SIZE(si)
  si.fMask = SIF_POS
  si.nPos = pos
  si.nTrackPos = 0
  SELF.SetScrollInfo(SB_HORZ, si, TRUE)
  SELF.GetScrollInfo(SB_HORZ, si)
  pos = si.nPos

  !- redraw if scroll pos changed
  IF SELF.scrollPos <> pos
    SELF.scrollPos = pos
    dc.GetDC(SELF)
    SELF.RedrawFramesImage(dc)
    dc.ReleaseDC()
  END
  
  RETURN FALSE

THorizontalImageSelector.OnMouseWheel PROCEDURE(UNSIGNED wParam)
distance                                SHORT, AUTO
vKey                                    SHORT, AUTO
action                                  USHORT, AUTO
  CODE
  distance = HIWORD(wParam)
  vKey = LOWORD(wParam)

  IF distance
    IF distance > 0
      action = SB_LINELEFT
    ELSE
      action = SB_LINERIGHT
    END
    SELF.SendMessage(WM_HSCROLL, action, 0)
    RETURN FALSE
  END
  RETURN TRUE

THorizontalImageSelector.OnLButtonDown    PROCEDURE(UNSIGNED wParam, LONG lParam)
dc                                          TDC
pt                                          LIKE(POINT)
rc                                          TRect
n                                           LONG, AUTO
  CODE
  SELF.GetClientRect(rc)
  
  !- pos on the visible image
  pt.x = GET_X_LPARAM(lParam)
  pt.y = GET_Y_LPARAM(lParam)

  !- pos on the big image
  pt.x += (SELF.framesImage.GetWidth() - rc.Width()) * SELF.scrollPos / 100
  
  !- find selected frame number
  n = (pt.x / (SELF.frameSize.cx + SELF.frameOutline.cx)) + 1
  
  !- check for outline clicked
  IF pt.x > ((n-1)*SELF.frameSize.cx + n*SELF.frameOutline.cx)
    IF SELF.currentFrame <> n
      SELF.SelectFrame(n)
      
      !- redraw the control
      dc.GetDC(SELF)
      SELF.RedrawFramesImage(dc)
      dc.ReleaseDC()
      
      !- don't call default handler DefSubclassProc
      RETURN FALSE
    END
  END
  
  !- call default handler DefSubclassProc
  RETURN TRUE
!!!endregion
