!* Image selector
!* mikeduglas@yandex.ru
!* 2022

  INCLUDE('winapi.inc'), ONCE
  INCLUDE('gdiplus.inc'), ONCE


!!!<summary>Abstract class.</summary>
TBaseImageSelector            CLASS(TWnd), TYPE, MODULE('imgsel.clw'), LINK('imgsel.clw')
framesCount                     UNSIGNED, PROTECTED
frameSize                       LIKE(SIZE), PROTECTED     !- size of each frame
framesData                      &typImgSelFramesData, PROTECTED
framesImage                     &TGdiPlusBitmap, PROTECTED
frameOutline                    LIKE(SIZE), PROTECTED     !- default: 10x10
scrollPos                       SIGNED, PROTECTED
currentFrame                    UNSIGNED, PROTECTED
bkColor                         LONG, PROTECTED           !- default: COLOR:White
selColor                        LONG, PROTECTED           !- default: COLOR:Red
selPenWidth                     UNSIGNED, PROTECTED       !- default: 3
orientation                     UNSIGNED, PROTECTED       !- 1: vertical, 2: horizontal
rAspectRatio                    SREAL, PROTECTED          !- frame_width/frame_height; default: 3/2
pixelFormat                     GpPixelFormat, PROTECTED  !- default: PixelFormat24bppRGB
scrollFactor                    UNSIGNED, PROTECTED       !- default: 3

Construct                       PROCEDURE()
Destruct                        PROCEDURE(), DERIVED
Init                            PROCEDURE(SIGNED pFeq), DERIVED
Kill                            PROCEDURE()
AddFile                         PROCEDURE(STRING pFileName, <STRING pDescr>)
!AddBlob                         PROCEDURE(BLOB pBlob, <STRING pDescr>)
AddRawData                      PROCEDURE(CONST *STRING pRawData, <STRING pDescr>)
SelectFrame                     PROCEDURE(UNSIGNED pFrameIndex), VIRTUAL
SetBackColor                    PROCEDURE(LONG pBackColor)
SetSelColor                     PROCEDURE(LONG pSelColor)
SetSelPenWidth                  PROCEDURE(UNSIGNED pPenWidth)
SetOutlineSize                  PROCEDURE(UNSIGNED pWidth, UNSIGNED pHeight)
SetAspectRatio                  PROCEDURE(SREAL pAspectRatio)
SetPixelFormat                  PROCEDURE(GpPixelFormat pFmt)
SetScrollFactor                 PROCEDURE(UNSIGNED pFactor)

PrepareControl                  PROCEDURE(), PROTECTED, VIRTUAL
CreateFramesImage               PROCEDURE(), PROTECTED, VIRTUAL
RedrawFramesImage               PROCEDURE(TDC pDc), PROTECTED, VIRTUAL
GetCurrentSelRect               PROCEDURE(*GpRectF pSelRect), PROTECTED, VIRTUAL
OnPaint                         PROCEDURE(), PROTECTED, VIRTUAL
OnVScroll                       PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnHScroll                       PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnMouseWheel                    PROCEDURE(UNSIGNED wParam), BOOL, PROTECTED, VIRTUAL
OnLButtonDown                   PROCEDURE(UNSIGNED wParam, LONG lParam), BOOL, PROTECTED, VIRTUAL
OnFrameSelected                 PROCEDURE(UNSIGNED pFrameIndex), PROTECTED, VIRTUAL
                              END


!!!<summary>Vertical selector.</summary>
TVerticalImageSelector        CLASS(TBaseImageSelector), TYPE, MODULE('imgsel.clw'), LINK('imgsel.clw')
PrepareControl                  PROCEDURE(), PROTECTED, DERIVED
                              END


!!!<summary>Horizontal selector.</summary>
THorizontalImageSelector      CLASS(TBaseImageSelector), TYPE, MODULE('imgsel.clw'), LINK('imgsel.clw')
PrepareControl                  PROCEDURE(), PROTECTED, DERIVED
                              END

