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


!- Raw image data
typImgSelFramesData           QUEUE, TYPE
Descr                           STRING(256)
ImageData                       ANY
                              END


WM_MOUSEWHEEL                 EQUATE(020Ah)
COLOR:WINDOWGRAY              EQUATE(0F0F0F0H)    !- default TAB background 

IMGSEL_ORIENTATION_VERTICAL   EQUATE(1)
IMGSEL_ORIENTATION_HORIZONTAL EQUATE(2)


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
  SELF.rAspectRatio = 3/2
  SELF.pixelFormat = PixelFormat24bppRGB
  SELF.scrollFactor = 3
  
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
g                                   TGdiPlusGraphics
pen                                 TGdiPlusPen
selRect                             LIKE(GpRectF)
  CODE
  IF SELF.currentFrame <> pFrameIndex
    g.FromImage(SELF.framesImage)
      
    !- selection rect
    SELF.GetCurrentSelRect(selRect)
    
    !- erase previous selection
    pen.CreatePen(GdipMakeARGB(SELF.bkColor), SELF.selPenWidth)
    g.DrawRectangle(pen, selRect)
    pen.DeletePen()
 
    !- draw new selection
    SELF.currentFrame = pFrameIndex
    IF SELF.currentFrame > 0 AND SELF.currentFrame <= SELF.framesCount
      CASE SELF.orientation
      OF IMGSEL_ORIENTATION_VERTICAL
        selRect.y = SELF.frameOutline.cy + (SELF.currentFrame-1)*(SELF.frameSize.cy+SELF.frameOutline.cy) - SELF.selPenWidth/2
      OF IMGSEL_ORIENTATION_HORIZONTAL
        selRect.x = SELF.frameOutline.cx + (SELF.currentFrame-1)*(SELF.frameSize.cx+SELF.frameOutline.cx) - SELF.selPenWidth/2
      END
      
      pen.CreatePen(GdipMakeARGB(SELF.selColor), SELF.selPenWidth)
      g.DrawRectangle(pen, selRect)
      pen.DeletePen()
    END

    g.DeleteGraphics()
    
    SELF.OnFrameSelected(SELF.currentFrame)
  END
  
TBaseImageSelector.SetBackColor   PROCEDURE(LONG pBackColor)
  CODE
  IF pBackColor <> COLOR:NONE
    IF BAND(pBackColor, 80000000h)
      SELF.bkColor = winapi::GetSysColor(BAND(pBackColor, 0ffffh))
    ELSE
      SELF.bkColor = pBackColor
    END
  ELSE
    IF 0{PROP:Gray}
      SELF.bkColor = COLOR:WINDOWGRAY
    ELSE
      SELF.bkColor = COLOR:WHITE
    END
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

TBaseImageSelector.SetAspectRatio PROCEDURE(SREAL pAspectRatio)
  CODE
  SELF.rAspectRatio = pAspectRatio
  
TBaseImageSelector.SetPixelFormat PROCEDURE(GpPixelFormat pFmt)
  CODE
  SELF.pixelFormat = pFmt
  
TBaseImageSelector.SetScrollFactor    PROCEDURE(UNSIGNED pFactor)
  CODE
  SELF.scrollFactor = pFactor
  IF SELF.scrollFactor = 0
    SELF.scrollFactor = 1
  END
  
TBaseImageSelector.PrepareControl PROCEDURE()
  CODE
  
TBaseImageSelector.CreateFramesImage  PROCEDURE()
rc                                      TRect
frame                                   TGdiPlusImage
thumbnail                               TGdiPlusImage
g                                       TGdiPlusGraphics
brush                                   TGdiPlusSolidBrush
x                                       SIGNED, AUTO
y                                       SIGNED, AUTO
i                                       LONG, AUTO
  CODE
  !- number of frames
  SELF.framesCount = RECORDS(SELF.framesData)
  IF SELF.framesCount = 0
    RETURN
  END
  
  !- calc frame size (width = height*1.5)
  SELF.GetClientRect(rc)
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    SELF.frameSize.cx = rc.Width() - SELF.frameOutline.cx * 2
    SELF.frameSize.cy = SELF.frameSize.cx / SELF.rAspectRatio
  OF IMGSEL_ORIENTATION_HORIZONTAL
    SELF.frameSize.cy = rc.Height() - SELF.frameOutline.cy * 2
    SELF.frameSize.cx = SELF.frameSize.cy * SELF.rAspectRatio
  END
  
  !- create image of combined thumbnails
  SELF.framesImage &= NEW TGdiPlusBitmap
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    SELF.framesImage.CreateBitmap(SELF.frameSize.cx + SELF.frameOutline.cx * 2, (SELF.frameSize.cy + SELF.frameOutline.cy) * SELF.framesCount + SELF.frameOutline.cy, SELF.pixelFormat)
  OF IMGSEL_ORIENTATION_HORIZONTAL
    SELF.framesImage.CreateBitmap((SELF.frameSize.cx + SELF.frameOutline.cx) * SELF.framesCount + SELF.frameOutline.cx, SELF.frameSize.cy + SELF.frameOutline.cy * 2, SELF.pixelFormat)
  END
  g.FromImage(SELF.framesImage)
  
  !- erase background
  brush.CreateSolidBrush(GdipMakeARGB(SELF.bkColor))
  g.FillRectangle(brush, 0, 0, SELF.framesImage.GetWidth(), SELF.framesImage.GetHeight())
  brush.DeleteBrush()
  
  !- loop thru all frames
  x = SELF.frameOutline.cx
  y = SELF.frameOutline.cy
  LOOP i=1 TO SELF.framesCount
    GET(SELF.framesData, i)
    !- create full image
    frame.FromString(SELF.framesData.ImageData)
    !- create thumbnail
    frame.GetThumbnailImage(SELF.frameSize.cx, SELF.frameSize.cy, thumbnail)
    !- append the thumbnail to combined image
    g.DrawImage(thumbnail, x, y, SELF.frameSize.cx, SELF.frameSize.cy)
    !- clean up frame image and its thumbnail
    frame.DisposeImage()
    thumbnail.DisposeImage()
    !- shift down/right
    CASE SELF.orientation
    OF IMGSEL_ORIENTATION_VERTICAL
      y += SELF.frameSize.cy + SELF.frameOutline.cy
    OF IMGSEL_ORIENTATION_HORIZONTAL
      x += SELF.frameSize.cx + SELF.frameOutline.cx
    END
  END
  
  !- select 1st frame
  SELF.SelectFrame(1)
  
  !- free data queue
  FREE(SELF.framesData)
  
TBaseImageSelector.RedrawFramesImage  PROCEDURE(TDC dc)
g                                       TGdiPlusGraphics
rc                                      TRect
destRect                                LIKE(GpRect)
srcRect                                 LIKE(GpRect)
  CODE
  g.FromHDC(dc.GetHandle())
  SELF.GetClientRect(rc)
  
  !- draw visible part of the image
  destRect.x=0
  destRect.y=0
  destRect.width=rc.Width()
  destRect.height=rc.Height()
  
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    srcRect.x=0
    srcRect.y=(SELF.framesImage.GetHeight() - rc.Height()) * SELF.scrollPos / 100
    srcRect.width=SELF.framesImage.GetWidth()
    srcRect.height=rc.Height()
  OF IMGSEL_ORIENTATION_HORIZONTAL
    srcRect.x=(SELF.framesImage.GetWidth() - rc.Width()) * SELF.scrollPos / 100
    srcRect.y=0
    srcRect.width=rc.Width()
    srcRect.height=SELF.framesImage.GetHeight()
  END

  g.DrawImage(SELF.framesImage, destRect, srcRect, UnitPixel)
  
TBaseImageSelector.GetCurrentSelRect  PROCEDURE(*GpRectF pSelRect)
  CODE
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    pSelRect.x = SELF.frameOutline.cx-SELF.selPenWidth/2
    pSelRect.y = SELF.frameOutline.cy + (SELF.currentFrame-1)*(SELF.frameSize.cy+SELF.frameOutline.cy) - SELF.selPenWidth/2
    pSelRect.width = SELF.frameSize.cx+SELF.selPenWidth
    pSelRect.height = SELF.frameSize.cy+SELF.selPenWidth
  OF IMGSEL_ORIENTATION_HORIZONTAL
    pSelRect.x = SELF.frameOutline.cx + (SELF.currentFrame-1)*(SELF.frameSize.cx+SELF.frameOutline.cx) - SELF.selPenWidth/2
    pSelRect.y = SELF.frameOutline.cy-SELF.selPenWidth/2
    pSelRect.width = SELF.frameSize.cx+SELF.selPenWidth
    pSelRect.height = SELF.frameSize.cy+SELF.selPenWidth
  ELSE
    printd('TBaseImageSelector.CalcNewSelection failed: invalid orientation.')
  END

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
rc                              TRect
dy                              UNSIGNED, AUTO
py                              UNSIGNED, AUTO
action                          USHORT, AUTO
pos                             SIGNED, AUTO
si                              LIKE(SCROLLINFO)
dc                              TDC
  CODE
  IF SELF.orientation = IMGSEL_ORIENTATION_VERTICAL
    SELF.GetClientRect(rc)
    dy = SELF.scrollFactor        !- line scroll pos
    py = 100 / SELF.framesCount   !- page scroll pos
    IF py < dy*2
      py = dy*2
    END
    
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
  END
  
  RETURN FALSE
    
TBaseImageSelector.OnHScroll  PROCEDURE(UNSIGNED wParam, LONG lParam)
rc                              TRect
dx                              UNSIGNED, AUTO
px                              UNSIGNED, AUTO
action                          USHORT, AUTO
pos                             SIGNED, AUTO
si                              LIKE(SCROLLINFO)
dc                              TDC
  CODE
  IF SELF.orientation = IMGSEL_ORIENTATION_HORIZONTAL
    SELF.GetClientRect(rc)
    dx = SELF.scrollFactor                !- line scroll pos
    px = 100 / SELF.framesCount           !- page scroll pos
    IF px < dx*2
      px = dx*2
    END

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
  END
  
  RETURN FALSE

TBaseImageSelector.OnMouseWheel   PROCEDURE(UNSIGNED wParam)
distance                            SHORT, AUTO
vKey                                SHORT, AUTO
action                              USHORT, AUTO
  CODE
  distance = HIWORD(wParam)
  vKey = LOWORD(wParam)

  IF distance
    CASE SELF.orientation
    OF IMGSEL_ORIENTATION_VERTICAL
      IF distance > 0
        action = SB_LINEUP
      ELSE
        action = SB_LINEDOWN
      END
      SELF.SendMessage(WM_VSCROLL, action, 0)
      
    OF IMGSEL_ORIENTATION_HORIZONTAL
      IF distance > 0
        action = SB_LINELEFT
      ELSE
        action = SB_LINERIGHT
      END
      SELF.SendMessage(WM_HSCROLL, action, 0)
    END
    
    RETURN FALSE
  END
  RETURN TRUE

TBaseImageSelector.OnLButtonDown  PROCEDURE(UNSIGNED wParam, LONG lParam)
dc                                  TDC
pt                                  LIKE(POINT)
rc                                  TRect
n                                   LONG(0)
bFrameClicked                       BOOL(FALSE)
  CODE
  SELF.GetClientRect(rc)
  
  !- pos on the visible image
  pt.x = GET_X_LPARAM(lParam)
  pt.y = GET_Y_LPARAM(lParam)

  !- pos on the big image
  !- find selected frame number
  !- check for outline clicked
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    pt.y += (SELF.framesImage.GetHeight() - rc.Height()) * SELF.scrollPos / 100
    n = (pt.y / (SELF.frameSize.cy + SELF.frameOutline.cy)) + 1
    bFrameClicked = CHOOSE(pt.y > ((n-1)*SELF.frameSize.cy + n*SELF.frameOutline.cy))
  OF IMGSEL_ORIENTATION_HORIZONTAL
    pt.x += (SELF.framesImage.GetWidth() - rc.Width()) * SELF.scrollPos / 100
    n = (pt.x / (SELF.frameSize.cx + SELF.frameOutline.cx)) + 1
    bFrameClicked = CHOOSE(pt.x > ((n-1)*SELF.frameSize.cx + n*SELF.frameOutline.cx))
  END
  
  IF bFrameClicked
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

TBaseImageSelector.OnFrameSelected    PROCEDURE(UNSIGNED pFrameIndex)
  CODE
  
!!!endregion

!!!region TVerticalImageSelector
TVerticalImageSelector.PrepareControl PROCEDURE()
  CODE
  SELF.orientation = IMGSEL_ORIENTATION_VERTICAL
  SELF.FEQ{PROP:VScroll} = TRUE
  SELF.ShowScrollBar(SB_VERT, TRUE)
!!!endregion

!!!!region THorizontalImageSelector
THorizontalImageSelector.PrepareControl   PROCEDURE()
  CODE
  SELF.orientation = IMGSEL_ORIENTATION_HORIZONTAL
  SELF.FEQ{PROP:HScroll} = TRUE
  SELF.ShowScrollBar(SB_HORZ, TRUE)
!!!endregion
