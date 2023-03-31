!* Image selector
!* mikeduglas@yandex.ru
!* 31.03.2023

  INCLUDE('winapi.inc'), ONCE
  INCLUDE('gdiplus.inc'), ONCE


!!!<summary>Abstract class.</summary>
TBaseImageSelector            CLASS(TWnd), TYPE, MODULE('imgsel.clw'), LINK('imgsel.clw')
framesCount                     UNSIGNED, PROTECTED             !- number of frames
thumbnailSize                   LIKE(SIZE), PROTECTED           !- size of each thumbnail
framesData                      &typImgSelFramesData, PROTECTED !- a list of images
framesImage                     &TGdiPlusBitmap, PROTECTED      !- combined image
framesActualSize                LIKE(SIZE), PROTECTED           !- size of full image
frameOutline                    LIKE(SIZE), PROTECTED           !- default: 10x10
scrollPos                       SIGNED, PROTECTED               !- scroll position (0..scrollMax)
scrollMax                       SIGNED, PROTECTED               !- default: 100
currentFrame                    UNSIGNED, PROTECTED             !- selected frame index
bkColor                         LONG, PROTECTED                 !- combined image background; default: COLOR:White
selColor                        LONG, PROTECTED                 !- selection color; default: COLOR:Red
frameBkColor                    LONG, PROTECTED                 !- frame background; default: COLOR:None
selPenWidth                     UNSIGNED, PROTECTED             !- selection pen width; default: 3
orientation                     UNSIGNED, PROTECTED             !- 1: vertical, 2: horizontal
rAspectRatio                    SREAL, PROTECTED                !- frame_width/frame_height; default: 3/2
pixelFormat                     GpPixelFormat, PROTECTED        !- default: PixelFormat24bppRGB
scrollFactor                    UNSIGNED, PROTECTED             !- default: 3
bRetainOriginalAspectRatio      BOOL, PROTECTED                 !- retain original aspect ratio; default: false
bCenterThumbnails               BOOL, PROTECTED                 !- if RetainOriginalAspectRatio is true, center thumbnails; default: false
visibleRect                     LIKE(GpRect), PROTECTED         !- part of combined image currenty visible

bDraggingEnabled                BOOL, PROTECTED                 !- https://stackoverflow.com/questions/6142206/what-is-the-proper-way-of-handling-a-mouse-drag
bDragModeActive                 BOOL, PROTECTED                 !- https://stackoverflow.com/questions/6142206/what-is-the-proper-way-of-handling-a-mouse-drag

Construct                       PROCEDURE()
Destruct                        PROCEDURE(), DERIVED
Init                            PROCEDURE(SIGNED pFeq), DERIVED
Kill                            PROCEDURE()
Reset                           PROCEDURE()
Refresh                         PROCEDURE()
AddFile                         PROCEDURE(STRING pFileName, <STRING pDescr>)
!AddBlob                         PROCEDURE(BLOB pBlob, <STRING pDescr>)
AddRawData                      PROCEDURE(*STRING pRawData, <STRING pDescr>)
SelectFrame                     PROCEDURE(UNSIGNED pFrameIndex, BOOL pForce=FALSE), VIRTUAL
EnsureVisible                   PROCEDURE(UNSIGNED pFrameIndex), VIRTUAL
SetBackColor                    PROCEDURE(LONG pBackColor)
SetSelColor                     PROCEDURE(LONG pSelColor)
SetFrameBackColor               PROCEDURE(LONG pBackColor)
SetSelPenWidth                  PROCEDURE(UNSIGNED pPenWidth)
SetOutlineSize                  PROCEDURE(UNSIGNED pWidth, UNSIGNED pHeight)
SetAspectRatio                  PROCEDURE(SREAL pAspectRatio)
SetPixelFormat                  PROCEDURE(GpPixelFormat pFmt)
SetScrollFactor                 PROCEDURE(UNSIGNED pFactor)
RetainOriginalAspectRatio       PROCEDURE(BOOL pValue)
CenterThumbnails                PROCEDURE(BOOL pValue)
NumberOfFrames                  PROCEDURE(), UNSIGNED
NumberOfVisibleFrames           PROCEDURE(), UNSIGNED
GetSelectedIndex                PROCEDURE(), UNSIGNED
UpdateFrameFromRawData          PROCEDURE(UNSIGNED pFrameIndex, *STRING pRawData)
UpdateFrame                     PROCEDURE(UNSIGNED pFrameIndex, STRING pFileName)
DeleteFrame                     PROCEDURE(UNSIGNED pFrameIndex)
EnableDragging                  PROCEDURE(BOOL pVal)

PrepareControl                  PROCEDURE(), PROTECTED, VIRTUAL
CreateFramesImage               PROCEDURE(), PROTECTED, VIRTUAL
RedrawFramesImage               PROCEDURE(TDC pDc), PROTECTED, VIRTUAL
GetCurrentSelRect               PROCEDURE(*GpRectF pSelRect), PROTECTED, VIRTUAL
GetSelRect                      PROCEDURE(UNSIGNED pFrameIndex, *TRect pSelRect), PROTECTED, VIRTUAL
GetSelRect                      PROCEDURE(UNSIGNED pFrameIndex, *GpRectF pSelRect), PROTECTED, VIRTUAL
CalcThumbnailSize               PROCEDURE(TGdiPlusImage pImage, SIZE pFrameSize, BOOL pDoCenter, *SIZE pThumbnailSize, *POINT pThumbnailPos), PROTECTED
DrawSelection                   PROCEDURE(TGdiPlusGraphics pGrahpics, UNSIGNED pFrameIndex, LONG pColor), PROTECTED

OnPaint                         PROCEDURE(), PROTECTED, VIRTUAL
OnVScroll                       PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnHScroll                       PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnScroll                        PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnMouseWheel                    PROCEDURE(UNSIGNED wParam), BOOL, PROTECTED, VIRTUAL
OnLButtonDown                   PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnLButtonUp                     PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnMouseMove                     PROCEDURE(UNSIGNED wParam, LONG lParam), PROTECTED, VIRTUAL
OnCaptureChanged                PROCEDURE(LONG lParam), PROTECTED, VIRTUAL
OnFrameSelected                 PROCEDURE(UNSIGNED pFrameIndex), PROTECTED, VIRTUAL
OnFrameRejected                 PROCEDURE(STRING pFrameDescr), PROTECTED, VIRTUAL
OnFrameDeleted                  PROCEDURE(UNSIGNED pFrameIndex), PROTECTED, VIRTUAL
OnDrop                          PROCEDURE(UNSIGNED pFrameIndex, POINT pPt), PROTECTED, VIRTUAL
                              END


!!!<summary>Vertical selector.</summary>
TVerticalImageSelector        CLASS(TBaseImageSelector), TYPE, MODULE('imgsel.clw'), LINK('imgsel.clw')
PrepareControl                  PROCEDURE(), PROTECTED, DERIVED
                              END


!!!<summary>Horizontal selector.</summary>
THorizontalImageSelector      CLASS(TBaseImageSelector), TYPE, MODULE('imgsel.clw'), LINK('imgsel.clw')
PrepareControl                  PROCEDURE(), PROTECTED, DERIVED
                              END

