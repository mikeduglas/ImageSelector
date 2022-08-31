  PROGRAM

  INCLUDE('imgsel.inc'), ONCE

  MAP
    INCLUDE('printf.inc'), ONCE
    ReadDir(STRING pDir)
  END

Window                        WINDOW('Vertical image selector'),AT(,,347,205),CENTER,GRAY,SYSTEM, |
                                FONT('Segoe UI',9),RESIZE
                                IMAGE,AT(2,2,180,125),USE(?ImgViewer)
                                PROMPT('Set in code'),AT(2,130),USE(?LblDescr)
                                IMAGE,AT(192,2,93),FULL,USE(?ImgSelector)
                                BUTTON('Select folder...'),AT(2,183,56),USE(?btnSelectFolder)
                                BUTTON('Up'),AT(297,15,40,14),USE(?btnScrollUp),ICON('ABUPROW.ICO'),LEFT
                                BUTTON('Down'),AT(297,39,40,14),USE(?btnScrollDown),ICON('ABDNROW.ICO'),LEFT
                                BUTTON('Update'),AT(297,113,40),USE(?btnUpdate)
                                BUTTON('Delete'),AT(297,137,40,14),USE(?btnDelete)
                              END


ThisImgSel                    CLASS(TVerticalImageSelector)
OnFrameSelected                 PROCEDURE(UNSIGNED pFrameIndex), PROTECTED, DERIVED
OnFrameRejected                 PROCEDURE(STRING pFrameDescr), PROTECTED, DERIVED
OnFrameDeleted                  PROCEDURE(UNSIGNED pFrameIndex), PROTECTED, DERIVED
                              END


imgFolder                     STRING(FILE:MaxFilePath)
QDir                          QUEUE(File:Queue),PRE(QDir)
FullPath                        STRING(FILE:MaxFileName)
                              END
i                             LONG, AUTO

  CODE
  !- Open window
  OPEN(Window)
  ?LblDescr{PROP:Text} = ''

  !- Initialize image selector
  ThisImgSel.Init(?ImgSelector)
  
  !- retain aspect ratios of original images
!  ThisImgSel.RetainOriginalAspectRatio(TRUE)
!  ThisImgSel.CenterThumbnails(TRUE)
  
  !- Add all image files from \images folder to the selector
  imgFolder = '.\images'
  ReadDir(imgFolder)
  
  ACCEPT
    CASE ACCEPTED()
    OF ?btnSelectFolder
      !- select another folder to show images from
      IF FILEDIALOG(, imgFolder, 'All files|*.*', FILE:LongName + FILE:Directory + FILE:KeepDir)
        !- rebuild image selector
        ThisImgSel.Reset()
        ReadDir(imgFolder)
        ThisImgSel.Refresh()
      END
      
    OF ?btnScrollDown
      DO R::ScrollDown
         
    OF ?btnScrollUp
      DO R::ScrollUp
      
    OF ?btnUpdate
      DO R::Update
      
    OF ?btnDelete
      DO R::Delete
    END
  END

  !- Clean up
  ThisImgSel.Kill()
  
  
R::ScrollDown                 ROUTINE
  DATA
frameIndex  UNSIGNED, AUTO
  CODE
  frameIndex = ThisImgSel.GetSelectedIndex()
  frameIndex += 1
  IF frameIndex > ThisImgSel.NumberOfFrames()
    frameIndex = 1
  END
  
  ThisImgSel.EnsureVisible(frameIndex)
  ThisImgSel.SelectFrame(frameIndex)
    
R::ScrollUp                   ROUTINE
  DATA
frameIndex  UNSIGNED, AUTO
  CODE
  frameIndex = ThisImgSel.GetSelectedIndex()
  frameIndex -= 1
  IF frameIndex = 0
    frameIndex = ThisImgSel.NumberOfFrames()
  END
  
  ThisImgSel.EnsureVisible(frameIndex)
  ThisImgSel.SelectFrame(frameIndex)

R::Update                     ROUTINE
  DATA
frameIndex  UNSIGNED, AUTO
sFileName   STRING(FILE:MaxFileName)
TempQDir    QUEUE(File:Queue),PRE(TempQDir)
            END
  CODE
  IF FILEDIALOG(, sFileName, |
    'Portable Network Graphics (*.png)|*.png|'&|
    'File Interchange Format (*.jpg)|*.jpg|'&|
    'Bitmap files (*.bmp)|*.bmp|'&|
    'Graphics Interchange Format (*.gif)|*.gif|'&|
    'Tagged Image File Format (*.tif)|*.tif', |
    FILE:LongName + FILE:AddExtension + FILE:KeepDir)
    
    !- get selected index
    frameIndex = ThisImgSel.GetSelectedIndex()
    !- replace QDir entry
    GET(QDir, frameIndex)
    IF NOT ERRORCODE()
      DIRECTORY(TempQDir, sFileName, ff_:NORMAL)
      GET(TempQDir, 1)
      QDir :=: TempQDir
      QDir.FullPath = sFileName
      PUT(QDir)
      !- replace thumbnail
      ThisImgSel.UpdateFrame(frameIndex, sFileName)
    END
  END
  
R::Delete                     ROUTINE
  DATA
frameIndex  UNSIGNED, AUTO
  CODE
  frameIndex = ThisImgSel.GetSelectedIndex()
  ThisImgSel.DeleteFrame(frameIndex)
  
ReadDir                       PROCEDURE(STRING pDir)
  CODE
  FREE(QDir)
  !- read all known image formats
  DIRECTORY(QDir, printf('%s\*.bmp', pDir), ff_:NORMAL)
  DIRECTORY(QDir, printf('%s\*.png', pDir), ff_:NORMAL)
  DIRECTORY(QDir, printf('%s\*.jpg', pDir), ff_:NORMAL)
  DIRECTORY(QDir, printf('%s\*.gif', pDir), ff_:NORMAL)
  DIRECTORY(QDir, printf('%s\*.wmf', pDir), ff_:NORMAL)
  DIRECTORY(QDir, printf('%s\*.emf', pDir), ff_:NORMAL)
  DIRECTORY(QDir, printf('%s\*.tif', pDir), ff_:NORMAL)
  DIRECTORY(QDir, printf('%s\*.ico', pDir), ff_:NORMAL)
  
  !- read all files, then remove non-images in OnFrameRejected handler.
!  DIRECTORY(QDir, printf('%s\*.*', pDir), ff_:NORMAL)
  
  SORT(QDir, QDir.Name)
  LOOP i=1 TO RECORDS(QDir)
    GET(QDir, i)
    QDir.FullPath = printf('%s\%s', pDir, QDir.Name)
    PUT(QDir)
    ThisImgSel.AddFile(QDir.FullPath, QDir.Name)
  END

  
!- Display selected image
ThisImgSel.OnFrameSelected    PROCEDURE(UNSIGNED pFrameIndex)
  CODE
  IF pFrameIndex > 0
    !- Get image file name from the queue
    GET(QDir, pFrameIndex)
    IF NOT ERRORCODE()
      ?ImgViewer{PROP:Text} = QDir.FullPath
      ?LblDescr{PROP:Text} = printf('%s (%s bytes)', QDir.Name, LEFT(FORMAT(QDir.Size, @n12_)))
    END
  ELSE
    !- No images
    ?ImgViewer{PROP:Text} = ''
    ?LblDescr{PROP:Text} = ''
  END
  
ThisImgSel.OnFrameRejected    PROCEDURE(STRING pFrameDescr)
  CODE
  !- remove the file from the queue
  QDir.Name = pFrameDescr
  GET(QDir, QDir.Name)
  IF NOT ERRORCODE()
    DELETE(QDir)
  END

ThisImgSel.OnFrameDeleted     PROCEDURE(UNSIGNED pFrameIndex)
  CODE
  !- remove the file from the queue
  GET(QDir, pFrameIndex)
  IF NOT ERRORCODE()
    DELETE(QDir)
  END
