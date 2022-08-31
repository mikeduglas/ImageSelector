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
  SELF.scrollPos = 0
  SELF.currentFrame = 0
  SELF.bRetainOriginalAspectRatio = FALSE
  SELF.bCenterThumbnails = FALSE
  SELF.frameBkColor = COLOR:NONE
  
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
  
TBaseImageSelector.Reset      PROCEDURE()
  CODE
  SELF.Kill()
  SELF.scrollPos = 0
  SELF.currentFrame = 0
  
TBaseImageSelector.Refresh    PROCEDURE()
  CODE
  SELF.InvalidateRect(FALSE)
    
  !- reset scrollbar
  SELF.SendMessage(WM_MOUSEWHEEL, 10000h, 0)

TBaseImageSelector.AddFile    PROCEDURE(STRING pFileName, <STRING pDescr>)
df                              TDiskFile
sData                           &STRING
  CODE
  sData &= df.LoadFile(pFileName)
  SELF.AddRawData(sData, pDescr)
  DISPOSE(sData)
  
TBaseImageSelector.AddRawData PROCEDURE(CONST *STRING pRawData, <STRING pDescr>)
  CODE
  IF SELF.framesData &= NULL
    SELF.framesData &= NEW typImgSelFramesData
  END
  
  CLEAR(SELF.framesData)
  SELF.framesData.Descr = pDescr
  SELF.framesData.ImageData = CLIP(pRawData)
  ADD(SELF.framesData)
  
TBaseImageSelector.SelectFrame    PROCEDURE(UNSIGNED pFrameIndex, BOOL pForce=FALSE)
dc                                  TDC
g                                   TGdiPlusGraphics
  CODE
  IF (NOT SELF.framesImage &= NULL) AND (pForce OR SELF.currentFrame <> pFrameIndex)
    g.FromImage(SELF.framesImage)
    
    !- erase previous selection
    SELF.DrawSelection(g, SELF.currentFrame, SELF.bkColor)
    
    !- draw new selection
    SELF.currentFrame = pFrameIndex
    IF SELF.currentFrame > 0 AND SELF.currentFrame <= SELF.framesCount
      SELF.DrawSelection(g, SELF.currentFrame, SELF.selColor)
    END

    g.DeleteGraphics()
    
    !- redraw the control
    dc.GetDC(SELF)
    SELF.RedrawFramesImage(dc)
    dc.ReleaseDC()

    !- Notify a host
    SELF.OnFrameSelected(SELF.currentFrame)
  END
  
TBaseImageSelector.EnsureVisible  PROCEDURE(UNSIGNED pFrameIndex)
rcClient                            TRect
rcVisible                           TRect
rcSelection                         TRect
rcHalfFrame                         TRect
scrollPos                           UNSIGNED, AUTO
dc                                  TDC
  CODE
  IF pFrameIndex < 1 OR pFrameIndex > SELF.framesCount
    RETURN
  END
  
  SELF.GetClientRect(rcClient)
  
  rcVisible.left = SELF.visibleRect.x
  rcVisible.top = SELF.visibleRect.y
  rcVisible.Width(SELF.visibleRect.width)
  rcVisible.Height(SELF.visibleRect.height)
  
  SELF.GetSelRect(pFrameIndex, rcSelection)
  
  !- allow a half of frame to be visible
  rcHalfFrame.Assign(rcSelection)
  rcHalfFrame.InflateRect(-rcSelection.Width()/2, -rcSelection.Height()/2)
  IF rcHalfFrame.Intersect(rcVisible)
    RETURN
  END

  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    scrollPos = rcSelection.top / SELF.framesActualSize.cy * 100
    SELF.SendMessage(WM_VSCROLL, BOR(SB_THUMBPOSITION, BSHIFT(scrollPos, 16)), 0)
  OF IMGSEL_ORIENTATION_HORIZONTAL
    scrollPos = rcSelection.left / SELF.framesActualSize.cx * 100
    SELF.SendMessage(WM_HSCROLL, BOR(SB_THUMBPOSITION, BSHIFT(scrollPos, 16)), 0)
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
  
TBaseImageSelector.SetFrameBackColor  PROCEDURE(LONG pBackColor)
  CODE
  IF pBackColor <> COLOR:NONE
    IF BAND(pBackColor, 80000000h)
      SELF.frameBkColor = winapi::GetSysColor(BAND(pBackColor, 0ffffh))
    ELSE
      SELF.frameBkColor = pBackColor
    END
  ELSE
    SELF.frameBkColor = COLOR:NONE
  END

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
  
TBaseImageSelector.RetainOriginalAspectRatio  PROCEDURE(BOOL pValue)
  CODE
  SELF.bRetainOriginalAspectRatio = pValue
  
TBaseImageSelector.CenterThumbnails   PROCEDURE(BOOL pValue)
  CODE
  SELF.bCenterThumbnails = pValue
  
TBaseImageSelector.NumberOfFrames PROCEDURE()
  CODE
  RETURN SELF.framesCount
  
TBaseImageSelector.NumberOfVisibleFrames  PROCEDURE()
rc                                          TRect
frameWidth                                  SREAL, AUTO
frameHeight                                 SREAL, AUTO
quotient                                    SREAL(0)
  CODE
  SELF.GetClientRect(rc)
  frameWidth = SELF.thumbnailSize.cx + SELF.frameOutline.cx*2
  frameHeight = SELF.thumbnailSize.cy + SELF.frameOutline.cy*2
  
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    quotient = rc.Height() / frameHeight
  OF IMGSEL_ORIENTATION_HORIZONTAL
    quotient = rc.Width() / frameWidth
  ELSE
    RETURN 0
  END
  
  IF SELF.framesCount >= quotient
    RETURN INT(quotient)+1
  ELSE
    RETURN SELF.framesCount
  END
  
TBaseImageSelector.GetSelectedIndex   PROCEDURE()
  CODE
  RETURN SELF.currentFrame
  
TBaseImageSelector.UpdateFrameFromRawData PROCEDURE(UNSIGNED pFrameIndex, CONST *STRING pRawData)
image                                       TGdiPlusImage
thumbnail                                   TGdiPlusImage
frameWidth                                  UNSIGNED, AUTO
frameHeight                                 UNSIGNED, AUTO
thumbnailSize                               LIKE(SIZE)
thumbnailPos                                LIKE(POINT)
bmpNew                                      &TGdiPlusBitmap
g                                           TGdiPlusGraphics
brush                                       TGdiPlusSolidBrush
bmpSize                                     LIKE(SIZE)      !- current size of combined image
srcUnit                                     GpUnit
srcRect                                     LIKE(GpRect)      !- rect to copy from
dstRect                                     LIKE(GpRect)      !- rect to copy to
  CODE
  IF pFrameIndex < 1 OR pFrameIndex > SELF.framesCount
    printd('TBaseImageSelector.UpdateFrameFromRawData(%i) failed: index out of range.', pFrameIndex)
    RETURN
  END
  
  IF image.FromString(pRawData) <> GpStatus:Ok
    printd('TBaseImageSelector.UpdateFrameFromRawData(%i) failed: unable to create an image..', pFrameIndex)
    image.DisposeImage()
    RETURN
  END

  !- erase previous selection
  g.FromImage(SELF.framesImage)
  SELF.DrawSelection(g, SELF.currentFrame, SELF.bkColor)
  g.DeleteGraphics()

  frameWidth = SELF.thumbnailSize.cx + SELF.frameOutline.cx
  frameHeight = SELF.thumbnailSize.cy + SELF.frameOutline.cy

  !- current bitmap size
  bmpSize.cx = SELF.framesActualSize.cx
  bmpSize.cy = SELF.framesActualSize.cy

  !- create new bitmap
  bmpNew &= NEW TGdiPlusBitmap
  bmpNew.CreateBitmap(bmpSize.cx, bmpSize.cy, SELF.pixelFormat)
  
  !- draw on bmpNew
  g.FromImage(bmpNew)
    
  !- erase background
  brush.CreateSolidBrush(GdipMakeARGB(SELF.bkColor))
  g.FillRectangle(brush, 0, 0, bmpSize.cx, bmpSize.cy)
  brush.DeleteBrush()

  !- copy the image above (or to the left of) deleting frame
  IF pFrameIndex > 1
    CASE SELF.orientation
    OF IMGSEL_ORIENTATION_VERTICAL
      srcRect.x = 0
      srcRect.y = 0
      srcRect.width = bmpSize.cx
      srcRect.height = (pFrameIndex-1) * frameHeight
    
      dstRect = srcRect
    
    OF IMGSEL_ORIENTATION_HORIZONTAL
      srcRect.x = 0
      srcRect.y = 0
      srcRect.width = (pFrameIndex-1) * frameWidth
      srcRect.height = bmpSize.cy
    
      dstRect = srcRect
    END

    g.DrawImage(SELF.framesImage, dstRect, srcRect, UnitPixel)
  END
  
  !- create thumbnail
  IF NOT SELF.bRetainOriginalAspectRatio
    !- make thumbnail equal to the frame
    thumbnailSize = SELF.thumbnailSize
    thumbnailPos.x = 0
    thumbnailPos.y = 0
  ELSE
    !- calculate thumbnail size to retain original aspect ratio
    thumbnailPos.x = 0
    thumbnailPos.y = 0
    SELF.CalcThumbnailSize(image, SELF.thumbnailSize, SELF.bCenterThumbnails, thumbnailSize, thumbnailPos)
  END
  image.GetThumbnailImage(thumbnailSize.cx, thumbnailSize.cy, thumbnail)
!  image.GetThumbnailImage(SELF.thumbnailSize.cx, SELF.thumbnailSize.cy, thumbnail)

  !- replace thumbnail
  srcRect.x = 0
  srcRect.y = 0
  srcRect.width = SELF.thumbnailSize.cx
  srcRect.height = SELF.thumbnailSize.cy

  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    dstRect.x = SELF.frameOutline.cx + thumbnailPos.x
    dstRect.y = SELF.frameOutline.cy + (pFrameIndex-1) * (SELF.thumbnailSize.cy+SELF.frameOutline.cy) + thumbnailPos.y
    dstRect.width = SELF.thumbnailSize.cx
    dstRect.height = SELF.thumbnailSize.cy
  OF IMGSEL_ORIENTATION_HORIZONTAL
    dstRect.x = SELF.frameOutline.cx + (pFrameIndex-1) * (SELF.thumbnailSize.cx+SELF.frameOutline.cx) + thumbnailPos.x
    dstRect.y = SELF.frameOutline.cy + thumbnailPos.y
    dstRect.width = SELF.thumbnailSize.cx
    dstRect.height = SELF.thumbnailSize.cy
  END
  g.DrawImage(thumbnail, dstRect, srcRect, UnitPixel)
  thumbnail.DisposeImage()
  image.DisposeImage()
  
  !- copy the image below (or to the right of) updating frame
  IF pFrameIndex < SELF.framesCount
    CASE SELF.orientation
    OF IMGSEL_ORIENTATION_VERTICAL
      srcRect.x = 0
      srcRect.y = pFrameIndex * frameHeight
      srcRect.width = bmpSize.cx
      srcRect.height = (SELF.framesCount - pFrameIndex) * frameHeight
    
      dstRect = srcRect

    OF IMGSEL_ORIENTATION_HORIZONTAL
      srcRect.x = pFrameIndex * frameWidth
      srcRect.y = 0
      srcRect.width = (SELF.framesCount - pFrameIndex) * frameWidth
      srcRect.height = bmpSize.cy
    
      dstRect = srcRect
    END
      
    g.DrawImage(SELF.framesImage, dstRect, srcRect, UnitPixel)
  END

  !- replace old bitmap with new one
  SELF.framesImage.DisposeImage()
  SELF.framesImage &= bmpNew
  
  !- clean up
  g.DeleteGraphics()
  
  !- refresh
  SELF.SelectFrame(SELF.currentFrame, TRUE)
  
TBaseImageSelector.UpdateFrame    PROCEDURE(UNSIGNED pFrameIndex, STRING pFileName)
df                                  TDiskFile
sData                               &STRING
  CODE
  sData &= df.LoadFile(pFileName)
  SELF.UpdateFrameFromRawData(pFrameIndex, sData)
  DISPOSE(sData)
  
TBaseImageSelector.DeleteFrame    PROCEDURE(UNSIGNED pFrameIndex)
frameWidth                          UNSIGNED, AUTO
frameHeight                         UNSIGNED, AUTO
bmpNew                              &TGdiPlusBitmap
g                                   TGdiPlusGraphics
brush                               TGdiPlusSolidBrush
bmpSize                             LIKE(SIZE)      !- current size of combined image
srcUnit                             GpUnit
srcRect                             LIKE(GpRect)      !- rect to copy from
dstRect                             LIKE(GpRect)      !- rect to copy to
selIndex                            UNSIGNED, AUTO
rc                                  TRect
  CODE
  IF pFrameIndex < 1 OR pFrameIndex > SELF.framesCount
    printd('TBaseImageSelector.DeleteFrame(%i) failed: index out of range.', pFrameIndex)
    RETURN
  END
      
  SELF.GetClientRect(rc)

  !- erase previous selection
  g.FromImage(SELF.framesImage)
  SELF.DrawSelection(g, SELF.currentFrame, SELF.bkColor)
  g.DeleteGraphics()

  frameWidth = SELF.thumbnailSize.cx + SELF.frameOutline.cx
  frameHeight = SELF.thumbnailSize.cy + SELF.frameOutline.cy

  !- current bitmap size
  bmpSize.cx = SELF.framesActualSize.cx
  bmpSize.cy = SELF.framesActualSize.cy

  !- reduce the size of deleting frame
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    bmpSize.cy -= frameHeight
    IF bmpSize.cy < rc.Height()
      bmpSize.cy = rc.Height()
    END
  OF IMGSEL_ORIENTATION_HORIZONTAL
    bmpSize.cx -= frameWidth
    IF bmpSize.cx < rc.Width()
      bmpSize.cx = rc.Width()
    END
  END

  !- create new bitmap
  bmpNew &= NEW TGdiPlusBitmap
  bmpNew.CreateBitmap(bmpSize.cx, bmpSize.cy, SELF.pixelFormat)
  
  !- draw on bmpNew
  g.FromImage(bmpNew)
    
  !- erase background
  brush.CreateSolidBrush(GdipMakeARGB(SELF.bkColor))
  g.FillRectangle(brush, 0, 0, bmpSize.cx, bmpSize.cy)
  brush.DeleteBrush()

  !- copy the image above (or to the left of) deleting frame
  IF pFrameIndex > 1
    CASE SELF.orientation
    OF IMGSEL_ORIENTATION_VERTICAL
      srcRect.x = 0
      srcRect.y = 0
      srcRect.width = bmpSize.cx
      srcRect.height = (pFrameIndex-1) * frameHeight
    
      dstRect = srcRect
    
    OF IMGSEL_ORIENTATION_HORIZONTAL
      srcRect.x = 0
      srcRect.y = 0
      srcRect.width = (pFrameIndex-1) * frameWidth
      srcRect.height = bmpSize.cy
    
      dstRect = srcRect
    END

    g.DrawImage(SELF.framesImage, dstRect, srcRect, UnitPixel)
  END

  !- copy the image below (or to the right of) deleting frame
  IF pFrameIndex < SELF.framesCount
    CASE SELF.orientation
    OF IMGSEL_ORIENTATION_VERTICAL
      srcRect.x = 0
      srcRect.y = pFrameIndex * frameHeight
      srcRect.width = bmpSize.cx
      srcRect.height = (SELF.framesCount - pFrameIndex) * frameHeight
    
      dstRect = srcRect
      dstRect.y -= frameHeight

    OF IMGSEL_ORIENTATION_HORIZONTAL
      srcRect.x = pFrameIndex * frameWidth
      srcRect.y = 0
      srcRect.width = (SELF.framesCount - pFrameIndex) * frameWidth
      srcRect.height = bmpSize.cy
    
      dstRect = srcRect
      dstRect.x -= frameWidth
    END
      
    g.DrawImage(SELF.framesImage, dstRect, srcRect, UnitPixel)
  END
  
  !- replace old bitmap with new one
  SELF.framesImage.DisposeImage()
  SELF.framesImage &= bmpNew
  
  !- clean up
  g.DeleteGraphics()
  
  !- update the selection
  IF pFrameIndex < SELF.currentFrame
    !- deleted frame is above selection
    selIndex = SELF.currentFrame-1
  ELSIF pFrameIndex > SELF.currentFrame
    !- deleted frame is below selection
    selIndex = SELF.currentFrame
  ELSE
    !- deleted frame is selected frame
    IF SELF.currentFrame = SELF.framesCount
      !- last frame selected
      selIndex = SELF.currentFrame-1      
    ELSE
      !- not last frame selected: retain selection
      selIndex = SELF.currentFrame
    END
  END

  !- change some properties
  SELF.framesCount -= 1
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    SELF.framesActualSize.cy -= frameHeight
    IF SELF.framesActualSize.cy < rc.Height()
      SELF.framesActualSize.cy = rc.Height()
    END
  OF IMGSEL_ORIENTATION_HORIZONTAL
    SELF.framesActualSize.cx -= frameWidth
    IF SELF.framesActualSize.cx < rc.Height()
      SELF.framesActualSize.cx = rc.Height()
    END
  END
    
  !- notify the host
  SELF.OnFrameDeleted(pFrameIndex)

  !- refresh
  SELF.SelectFrame(selIndex, TRUE)
  
TBaseImageSelector.PrepareControl PROCEDURE()
  CODE
  
TBaseImageSelector.CreateFramesImage  PROCEDURE()
rc                                      TRect
frame                                   TGdiPlusImage
thumbnail                               TGdiPlusImage
thumbnailPos                            LIKE(POINT)
thumbnailSize                           LIKE(SIZE)
g                                       TGdiPlusGraphics
brush                                   TGdiPlusSolidBrush
frameBrush                              TGdiPlusSolidBrush
bFillFrameBackground                    BOOL(FALSE)
x                                       SIGNED, AUTO
y                                       SIGNED, AUTO
numEntries                              UNSIGNED, AUTO
i                                       LONG, AUTO
  CODE
  SELF.GetClientRect(rc)

  !- number of entries
  numEntries = RECORDS(SELF.framesData)
  
  !- calc frame size (width = height*1.5)
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    SELF.thumbnailSize.cx = rc.Width() - SELF.frameOutline.cx * 2
    SELF.thumbnailSize.cy = SELF.thumbnailSize.cx / SELF.rAspectRatio
  OF IMGSEL_ORIENTATION_HORIZONTAL
    SELF.thumbnailSize.cy = rc.Height() - SELF.frameOutline.cy * 2
    SELF.thumbnailSize.cx = SELF.thumbnailSize.cy * SELF.rAspectRatio
  END
  
  !- create image of combined thumbnails
  SELF.framesImage &= NEW TGdiPlusBitmap
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    SELF.framesActualSize.cx = SELF.thumbnailSize.cx + SELF.frameOutline.cx * 2
    SELF.framesActualSize.cy = (SELF.thumbnailSize.cy + SELF.frameOutline.cy) * numEntries + SELF.frameOutline.cy
    IF SELF.framesActualSize.cy < rc.Height()
      SELF.framesActualSize.cy = rc.Height()
    END
  OF IMGSEL_ORIENTATION_HORIZONTAL
    SELF.framesActualSize.cx = (SELF.thumbnailSize.cx + SELF.frameOutline.cx) * numEntries + SELF.frameOutline.cx
    SELF.framesActualSize.cy = SELF.thumbnailSize.cy + SELF.frameOutline.cy * 2
    IF SELF.framesActualSize.cx < rc.Width()
      SELF.framesActualSize.cx = rc.Width()
    END
  END
  SELF.framesImage.CreateBitmap(SELF.framesActualSize.cx, SELF.framesActualSize.cy, SELF.pixelFormat)
  g.FromImage(SELF.framesImage)
  
  !- erase background
  brush.CreateSolidBrush(GdipMakeARGB(SELF.bkColor))
  g.FillRectangle(brush, 0, 0, SELF.framesActualSize.cx, SELF.framesActualSize.cy)
  brush.DeleteBrush()
  
  IF SELF.bRetainOriginalAspectRatio AND SELF.frameBkColor <> COLOR:NONE
    bFillFrameBackground = TRUE
    frameBrush.CreateSolidBrush(GdipMakeARGB(SELF.frameBkColor))
  END
  
  !- loop thru all entries
  SELF.framesCount = 0
  x = SELF.frameOutline.cx
  y = SELF.frameOutline.cy
  LOOP i=1 TO numEntries
    GET(SELF.framesData, i)
    !- create combined image.
    !- ignore those frames with null or empty data.
    IF NOT SELF.framesData.ImageData &= NULL AND LEN(SELF.framesData.ImageData) > 0 AND frame.FromString(SELF.framesData.ImageData) = GpStatus:Ok
      !- count the images
      SELF.framesCount += 1
      
      !- create thumbnail
      IF NOT SELF.bRetainOriginalAspectRatio
        !- don't change thumbnail size
        thumbnailSize = SELF.thumbnailSize
        thumbnailPos.x = x
        thumbnailPos.y = y
      ELSE
        !- calculate thumbnail size to retain original aspect ratio
        thumbnailPos.x = x
        thumbnailPos.y = y
        SELF.CalcThumbnailSize(frame, SELF.thumbnailSize, SELF.bCenterThumbnails, thumbnailSize, thumbnailPos)
      END
      frame.GetThumbnailImage(thumbnailSize.cx, thumbnailSize.cy, thumbnail)
      
      !- frame bacjkground
      IF bFillFrameBackground AND SELF.frameBkColor <> COLOR:NONE
        g.FillRectangle(frameBrush, x, y, SELF.thumbnailSize.cx, SELF.thumbnailSize.cy)
      END
      
      !- append the thumbnail to combined image
      g.DrawImage(thumbnail, thumbnailPos.x, thumbnailPos.y, thumbnailSize.cx, thumbnailSize.cy)
      
      !- clean up frame image and its thumbnail
      frame.DisposeImage()
      thumbnail.DisposeImage()
      !- shift down/right
      CASE SELF.orientation
      OF IMGSEL_ORIENTATION_VERTICAL
        y += SELF.thumbnailSize.cy + SELF.frameOutline.cy
      OF IMGSEL_ORIENTATION_HORIZONTAL
        x += SELF.thumbnailSize.cx + SELF.frameOutline.cx
      END
    ELSE
      !- Notify a host that the entry is not an image
      SELF.OnFrameRejected(SELF.framesData.Descr)
    END
  END
  
  IF SELF.framesCount < numEntries
    !- if we allocated image size for non-image entries, reduce combined image szie
    CASE SELF.orientation
    OF IMGSEL_ORIENTATION_VERTICAL
      SELF.framesActualSize.cy = (SELF.thumbnailSize.cy + SELF.frameOutline.cy) * SELF.framesCount + SELF.frameOutline.cy
    OF IMGSEL_ORIENTATION_HORIZONTAL
      SELF.framesActualSize.cx = (SELF.thumbnailSize.cx + SELF.frameOutline.cx) * SELF.framesCount + SELF.frameOutline.cx
    END
  END
  
  !- select 1st frame
  IF SELF.framesCount > 0
    SELF.SelectFrame(1)
  ELSE
    !- Notify a host that no available images
    SELF.OnFrameSelected(0)
  END
  
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
    srcRect.y=(SELF.framesActualSize.cy - rc.Height()) * SELF.scrollPos / 100
    srcRect.width=SELF.framesActualSize.cx
    srcRect.height=destRect.height
    
  OF IMGSEL_ORIENTATION_HORIZONTAL
    srcRect.x=(SELF.framesActualSize.cx - rc.Width()) * SELF.scrollPos / 100
    srcRect.y=0
    srcRect.width=destRect.width
    srcRect.height=SELF.framesActualSize.cy
  END
  
  g.DrawImage(SELF.framesImage, destRect, srcRect, UnitPixel)
  
  SELF.visibleRect = srcRect
  
TBaseImageSelector.GetCurrentSelRect  PROCEDURE(*GpRectF pSelRect)
  CODE
  SELF.GetSelRect(SELF.currentFrame, pSelRect)
  
TBaseImageSelector.GetSelRect PROCEDURE(UNSIGNED pFrameIndex, *GpRectF pSelRect)
  CODE
  CASE SELF.orientation
  OF IMGSEL_ORIENTATION_VERTICAL
    pSelRect.x = SELF.frameOutline.cx-SELF.selPenWidth/2
    pSelRect.y = SELF.frameOutline.cy + (pFrameIndex-1)*(SELF.thumbnailSize.cy+SELF.frameOutline.cy) - SELF.selPenWidth/2
    pSelRect.width = SELF.thumbnailSize.cx+SELF.selPenWidth
    pSelRect.height = SELF.thumbnailSize.cy+SELF.selPenWidth
  OF IMGSEL_ORIENTATION_HORIZONTAL
    pSelRect.x = SELF.frameOutline.cx + (pFrameIndex-1)*(SELF.thumbnailSize.cx+SELF.frameOutline.cx) - SELF.selPenWidth/2
    pSelRect.y = SELF.frameOutline.cy-SELF.selPenWidth/2
    pSelRect.width = SELF.thumbnailSize.cx+SELF.selPenWidth
    pSelRect.height = SELF.thumbnailSize.cy+SELF.selPenWidth
  ELSE
    printd('TBaseImageSelector.GetFrameRect(%i) failed: invalid orientation.', pFrameIndex)
  END

TBaseImageSelector.GetSelRect PROCEDURE(UNSIGNED pFrameIndex, *TRect pSelRect)
rc                              LIKE(GpRectF)
  CODE
  SELF.GetSelRect(pFrameIndex, rc)
  pSelRect.Assign(rc.x, rc.y, rc.x+rc.width, rc.y+rc.height)
  
TBaseImageSelector.CalcThumbnailSize  PROCEDURE(TGdiPlusImage pImage, SIZE pFrameSize, BOOL pDoCenter, *SIZE pThumbnailSize, *POINT pThumbnailPos)
rImageWidth                             REAL, AUTO
rImageHeight                            REAL, AUTO
rFrameWidth                             REAL, AUTO
rFrameHeight                            REAL, AUTO
rImageAspectRatio                       REAL, AUTO
rFrameAspectRatio                       REAL, AUTO
nNewWidth                               UNSIGNED, AUTO
nNewHeight                              UNSIGNED, AUTO
  CODE
  rImageWidth = pImage.GetWidth()
  rImageHeight = pImage.GetHeight()
  rImageAspectRatio = rImageWidth / rImageHeight
  
  rFrameWidth = pFrameSize.cx
  rFrameHeight = pFrameSize.cy
  rFrameAspectRatio = rFrameWidth / rFrameHeight
  
  IF rImageAspectRatio > rFrameAspectRatio
    nNewHeight = rFrameWidth / rImageWidth * rImageHeight
    pThumbnailSize.cx = rFrameWidth
    pThumbnailSize.cy = nNewHeight
    IF pDoCenter
      pThumbnailPos.y += (rFrameHeight - nNewHeight)/2
    END
  ELSIF rFrameAspectRatio > rImageAspectRatio
    nNewWidth = rFrameHeight / rImageHeight * rImageWidth
    pThumbnailSize.cx = nNewWidth
    pThumbnailSize.cy = rFrameHeight
    IF pDoCenter
      pThumbnailPos.x += (rFrameWidth - nNewWidth)/2
    END
  ELSE
    pThumbnailSize = pFrameSize
  END
  
TBaseImageSelector.DrawSelection  PROCEDURE(TGdiPlusGraphics pGrahpics, UNSIGNED pFrameIndex, LONG pColor)
selRect                             LIKE(GpRectF)
pen                                 TGdiPlusPen
  CODE
  SELF.GetSelRect(pFrameIndex, selRect)
  pen.CreatePen(GdipMakeARGB(pColor), SELF.selPenWidth)
  pGrahpics.DrawRectangle(pen, selRect)
  pen.DeletePen()

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
    
  !- I know that SB_LINEUP and SB_LINELEFT have same value.

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
    pt.y += (SELF.framesActualSize.cy - rc.Height()) * SELF.scrollPos / 100
    n = (pt.y / (SELF.thumbnailSize.cy + SELF.frameOutline.cy)) + 1
    bFrameClicked = CHOOSE(pt.y > ((n-1)*SELF.thumbnailSize.cy + n*SELF.frameOutline.cy))
  OF IMGSEL_ORIENTATION_HORIZONTAL
    pt.x += (SELF.framesActualSize.cx - rc.Width()) * SELF.scrollPos / 100
    n = (pt.x / (SELF.thumbnailSize.cx + SELF.frameOutline.cx)) + 1
    bFrameClicked = CHOOSE(pt.x > ((n-1)*SELF.thumbnailSize.cx + n*SELF.frameOutline.cx))
  END
  
  IF bFrameClicked AND n > 0 AND n <= SELF.framesCount
    IF SELF.currentFrame <> n
      SELF.SelectFrame(n)
      
      !- don't call default handler DefSubclassProc
      RETURN FALSE
    END
  END
  
  !- call default handler DefSubclassProc
  RETURN TRUE

TBaseImageSelector.OnFrameSelected    PROCEDURE(UNSIGNED pFrameIndex)
  CODE
    
TBaseImageSelector.OnFrameRejected    PROCEDURE(STRING pFrameDescr)
  CODE

TBaseImageSelector.OnFrameDeleted PROCEDURE(UNSIGNED pFrameIndex)
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
