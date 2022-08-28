  PROGRAM

  INCLUDE('imgsel.inc'), ONCE

  MAP
    INCLUDE('printf.inc'), ONCE
    ReadDir(STRING pDir)
  END

Window                        WINDOW('Vertical image selector'),AT(,,286,205),CENTER,GRAY,SYSTEM, |
                                FONT('Segoe UI',9),RESIZE
                                IMAGE,AT(2,2,180,125),USE(?ImgViewer)
                                PROMPT('Set in code'),AT(2,130),USE(?LblDescr)
                                IMAGE,AT(192,2,93),FULL,USE(?ImgSelector)
                                BUTTON('Select folder'),AT(9,186,49),USE(?btnSelectFolder)
                              END


ThisImgSel                    CLASS(TVerticalImageSelector)
OnFrameSelected                 PROCEDURE(UNSIGNED pFrameIndex), PROTECTED, DERIVED
OnFrameRejected                 PROCEDURE(STRING pFrameDescr), PROTECTED, DERIVED
                              END


imgFolder                     STRING(FILE:MaxFilePath)
QDir                          QUEUE(File:Queue),PRE(QDir)
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
    END
  END

  !- Clean up
  ThisImgSel.Kill()
  
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
  LOOP i=1 TO RECORDS(QDir)
    GET(QDir, i)
    ThisImgSel.AddFile(printf('%s\%s', pDir, QDir.Name), QDir.Name)
  END

  
!- Display selected image
ThisImgSel.OnFrameSelected    PROCEDURE(UNSIGNED pFrameIndex)
  CODE
  IF pFrameIndex > 0
    !- Get image file name from the queue
    GET(QDir, pFrameIndex)
    IF NOT ERRORCODE()
      ?ImgViewer{PROP:Text} = printf('%s\%s', imgFolder, QDir.Name)
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
