VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "vtkConfigurationManagerExcel"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit
Implements vtkConfigurationManager
'---------------------------------------------------------------------------------------
' Module    : vtkConfigurationManagerExcel, implements vtkConfigurationManager
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : Manage Configurations and Modules of a VTK Project
'               - a Configuration is an Excel file containing Modules
'               - for each configuration, a Module can be imported/exported to a specific path relative to the VTK Project directory
'               - each configuration is a VBA project included in a specific Excel file whose path is relative to the VTK Project directory
'
' Usage:
'   - Each instance of Configuration Manager is attached to the DEV Excel Worksheet of a VTK project)
'       - the method vtkConfigurationManagerForProject of module vtkConfigurationManagers give the instance attached to a project, or create it
'   - a VTK project is implemented by a main Excel file containing a sheet named "vtkConfigurations"
'       - if such a sheet doesn't exist, it is created
'   - When initializing an instance, the relative development project workbook must be opened
'       - else initialization is not performed
'
' To implement later
'   - automatic recognition of the configuration sheet version, and proposal to the user to convert to the last version
'       cell $A$1 contains the version identification of the sheet version like "vtkConfigurations v1.0"
'
' Copyright 2013 Skwal-Soft (http://skwalsoft.com)
'
'   Licensed under the Apache License, Version 2.0 (the "License");
'   you may not use this file except in compliance with the License.
'   You may obtain a copy of the License at
'
'       http://www.apache.org/licenses/LICENSE-2.0
'
'   Unless required by applicable law or agreed to in writing, software
'   distributed under the License is distributed on an "AS IS" BASIS,
'   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
'   See the License for the specific language governing permissions and
'   limitations under the License.
'---------------------------------------------------------------------------------------

Private m_projectName As String             ' The configuration of a project is attached to the DEV Excel file
Private m_workbook As Workbook
Private m_configurationSheet As Worksheet
Private m_rootPath As String
Private m_refManager As vtkReferenceManager
Private m_devConfiguration As Integer
Private Const sheetName As String = "vtkConfigurations"
Private Const currentVersion As String = "vtkConfigurations v1.1"
Private Const version10 As String = "vtkConfigurations v1.0"
Private m_sheetVersion As String
Private Const nbTitleColumns As Integer = 1
Private Const nameLine = 1
Private Const pathLine = 2
Private Const templateLine = 3
Private Const projectNameLine = 4
Private Const commentLine = 5

Private Sub Class_Initialize()
    m_devConfiguration = -1
End Sub

Private Sub Class_Terminate()
    Set m_configurationSheet = Nothing
    Set m_workbook = Nothing
    Set m_refManager = Nothing
End Sub

'---------------------------------------------------------------------------------------
' Property  : projectName as String - Read/Write - Public
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : name of the project attached to this configuration manager
'               - when changed, the configurationWorkSheet private property is seset
' NOTE      : This is the Default property
'               - "Attribute Value.VB_UserMemId = 0" is added as first line of property Get (in exported Module)
' WARNING   : The attribute must be explicitly added after each export, or just before import
'---------------------------------------------------------------------------------------
'
Public Property Get projectName() As String
    projectName = m_projectName
End Property

Public Property Get vtkConfigurationManager_projectName() As String
    vtkConfigurationManager_projectName = projectName
End Property

Public Property Let projectName(ByVal sprojectName As String)
Attribute projectName.VB_UserMemId = 0
    Dim wbName As String
    wbName = vtkProjectForName(sprojectName).workbookDEVName
    If m_projectName <> sprojectName And VtkWorkbookIsOpen(wbName) Then
        m_projectName = sprojectName
        Set m_workbook = Workbooks(wbName)
        m_rootPath = ""
        setConfigurationSheet      ' Reset the configuration sheet when the attached project is changed
    End If
End Property

'---------------------------------------------------------------------------------------
' Property  : workbook as WorkBook - Read Only - Private
' Author    : Jean-Pierre Imbert
' Date      : 09/08/2013
' Purpose   : return the workbook containing the project
'---------------------------------------------------------------------------------------
'
Private Property Get Workbook() As Workbook
    Set Workbook = m_workbook
End Property

'---------------------------------------------------------------------------------------
' Function  : defaultProjectNameWithNumber as String - Read Only - Private
' Author    : Jean-Pierre Imbert
' Date      : 08/06/2014
' Purpose   : return the default projectName of a configuration given its number
'---------------------------------------------------------------------------------------
'
Private Function defaultProjectNameWithNumber(n As Integer) As String
    defaultProjectNameWithNumber = Me.configuration(n)
End Function

'---------------------------------------------------------------------------------------
' Function  : defaultCommentWithNumber as String - Read Only - Private
' Author    : Jean-Pierre Imbert
' Date      : 08/06/2014
' Purpose   : return the default comment of a configuration given its number
'---------------------------------------------------------------------------------------
'
Private Function defaultCommentWithNumber(n As Integer) As String
    defaultCommentWithNumber = "Project " & Me.configuration(n)
End Function

'---------------------------------------------------------------------------------------
' Function  : defaultTemplateWithNumber as String - Read Only - Private
' Author    : Jean-Pierre Imbert
' Date      : 01/07/2014
' Purpose   : return the default Excel template path of a configuration given its number
'---------------------------------------------------------------------------------------
'
Private Function defaultTemplateWithNumber(n As Integer) As String
    defaultTemplateWithNumber = ""
End Function

'---------------------------------------------------------------------------------------
' Property  : rootPath as String - Read Only - Public
' Author    : Jean-Pierre Imbert
' Date      : 09/08/2013
' Purpose   : return the rootPath of the project if the Excel file was already saved
'             - or return "" if the rootPath can't be determined
'             - the rootPath is cached when identified the first time
'---------------------------------------------------------------------------------------
'
Public Property Get rootPath() As String
    Dim ret As String
    If Not m_rootPath Like "" Then
        ret = m_rootPath
       Else
        ret = ""
        If Not Workbook Is Nothing Then
            ret = Workbook.path
            If Not ret Like "" Then
                Dim fso As New FileSystemObject
                ret = fso.GetParentFolderName(ret)
                m_rootPath = ret
            End If
        End If
    End If
    rootPath = ret
End Property

Public Property Get vtkConfigurationManager_rootPath() As String
    vtkConfigurationManager_rootPath = rootPath
End Property

'---------------------------------------------------------------------------------------
' Function  : isConfigurationInitializedForWorkbook
' Author    : Jean-Pierre Imbert
' Date      : 08/08/2013
' Purpose   : return True if a configuration sheet is already initialized in the workbook
'             - the parameter is an Excel Workbook name
'             - the Excel Workbook must be opened
' WARNING   : the configuration manager must not be initialized with a project name
'             because the project name setting implies the configuration sheet initialization
'---------------------------------------------------------------------------------------
'
Public Function isConfigurationInitializedForWorkbook(ExcelName As String) As Boolean
    Dim ws As Worksheet
   On Error Resume Next
    Set ws = Workbooks(ExcelName).Worksheets(sheetName)
   On Error GoTo 0
    isConfigurationInitializedForWorkbook = Not (ws Is Nothing)
End Function

'---------------------------------------------------------------------------------------
' Function  : nbTitleRows
' Author    : Jean-Pierre Imbert
' Date      : 08/06/2014
' Purpose   : return the number of Title rows in the configuration sheet depend on its version
'             - 2 for v1.0, 4 for 1.1
'---------------------------------------------------------------------------------------
'
Private Function nbTitleRows() As Integer
    If m_sheetVersion = version10 Then nbTitleRows = 2
    If m_sheetVersion = currentVersion Then nbTitleRows = 5
End Function

'---------------------------------------------------------------------------------------
' Procedure : setConfigurationSheet
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : set then configurationSheet property
'               - Create and initialize the sheet if it doesn't exist in the Project file
'---------------------------------------------------------------------------------------
'
Private Sub setConfigurationSheet()
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = Workbook.Worksheets(sheetName)
    On Error GoTo 0
    If ws Is Nothing Then        ' If the Configuration doesn't exist, create one
        Set ws = Workbook.Worksheets.Add(Type:=xlWorksheet)
        ws.name = sheetName
        '   Initialize the configuration sheet
        initializeConfigurationSheet ws
        End If
    ' Verify that the configuration sheet is in last known version
    If ws.Range("A1") <> currentVersion Then
        If ws.Range("A1") <> version10 Then
        ' Code to convert from previous version will be implemented here or in a specific method
            Else
            m_sheetVersion = version10
            End If
        Else
        m_sheetVersion = currentVersion
        End If
    '   Set the initialized worksheet property
    Set m_configurationSheet = ws
End Sub

'---------------------------------------------------------------------------------------
' Procedure : initializeConfigurationSheet
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : Initialize a new configuration sheet
'---------------------------------------------------------------------------------------
'
Private Sub initializeConfigurationSheet(ws As Worksheet)
    ws.Range("A1") = currentVersion
    ws.Range("A2") = ""
    ws.Range("A3") = "Path, template, name and comment"
    ws.Range("A4") = ""
    ws.Range("A5") = "Module Name"
    ws.Range("B1") = vtkProjectForName(projectName).projectName
    ws.Range("B2") = vtkProjectForName(projectName).projectStandardRelativePath
    ws.Range("C1") = vtkProjectForName(projectName).projectDEVName
    ws.Range("C2") = vtkProjectForName(projectName).projectDEVStandardRelativePath
    
    m_devConfiguration = 2
    
    ws.Columns("A:C").ColumnWidth = 22
    ws.Range("A1").Font.Size = 8
    ws.Range("A3").HorizontalAlignment = xlCenter
    ws.Range("A5").HorizontalAlignment = xlCenter
    ws.Range("A5").Font.Bold = True
    ws.Range("B1:C2").HorizontalAlignment = xlCenter
    ws.Range("B1:C1").Font.Bold = True
End Sub

'---------------------------------------------------------------------------------------
' Procedure : updateConfigurationSheetFormat
' Author    : Jean-Pierre Imbert
' Date      : 08/06/2014
' Purpose   : Update the configuration sheet to the current version
'---------------------------------------------------------------------------------------
'
Public Sub updateConfigurationSheetFormat()
    Dim ws As Worksheet
    
    If m_sheetVersion = version10 Then
        Set ws = configurationSheet
         
        ws.Rows("3:5").EntireRow.Insert     ' Insert new lines for the new format
        
        ws.Range("A1") = currentVersion
        ws.Range("A2") = ""
        ws.Range("A3") = "Path, template, name and comment"
        ws.Range("A4") = ""
        ws.Range("A5") = "Module Name"
    
        ws.Range("A2").Font.Bold = False
        ws.Range("A3").Font.Bold = False
        ws.Range("A3").HorizontalAlignment = xlCenter
        ws.Range("A5").HorizontalAlignment = xlCenter
        ws.Range("A5").Font.Bold = True
        
        m_sheetVersion = currentVersion     ' Set the sheetVersion for correct behavior after conversion
    End If

End Sub

'---------------------------------------------------------------------------------------
' Procedure : configurationSheet as Worksheet - Read only - Public
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : Return the configuration Sheet - used during tests
'---------------------------------------------------------------------------------------
'
Public Property Get configurationSheet() As Worksheet
    Set configurationSheet = m_configurationSheet
End Property

'---------------------------------------------------------------------------------------
' Property  : configurationCount as Integer - Read Only - Public
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : Get the number of configurations
'---------------------------------------------------------------------------------------
'
Public Property Get configurationCount() As Integer
    ' The number of configurations is the number of used columns minus one
    configurationCount = configurationSheet.UsedRange.Columns.Count - 1
End Property

Public Property Get vtkConfigurationManager_configurationCount() As Integer
    vtkConfigurationManager_configurationCount = configurationCount
End Property

'---------------------------------------------------------------------------------------
' Function  : configuration
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : return the n-th configuration of the project, given n as integer
'               - return "" if the configuration is inexistant
'---------------------------------------------------------------------------------------
'
Public Function configuration(n As Integer) As String
    Dim sResult As String
    sResult = ""
    If n >= 1 And n <= configurationCount Then
        sResult = configurationSheet.Cells(1, n + nbTitleColumns)
       Else
        sResult = ""
    End If
    configuration = sResult
End Function

Public Function vtkConfigurationManager_configuration(n As Integer) As String
    vtkConfigurationManager_configuration = configuration(n)
End Function

'---------------------------------------------------------------------------------------
' Procedure : addConfiguration
' Author    : Jean-Pierre Imbert
' Date      : 28/08/2013
' Purpose   : Add a configuration to the configuration manager
'             - optionaly a Path, a projectName and a Comment may be given for the configuration
'             - all modules pathes are initialized to Null
'             - if the configuration already exists, it is not added
' Return    : the number of the added configuration
'             - if the configuration already exists, return minus the configuration number
'---------------------------------------------------------------------------------------
'
Public Function addConfiguration(configuration As String, Optional path As String = "", Optional template As String = "", Optional projectName As String = "", Optional comment As String = "") As Integer
    Dim n As Integer
    n = getConfigurationNumber(configuration)
    If n = 0 Then   ' n = 0 means non-existant configuration
        n = configurationCount + 1                                        ' Set configuration number
        configurationSheet.Cells(1, n + nbTitleColumns) = configuration   ' Write configuration name
        configurationSheet.Cells(2, n + nbTitleColumns) = path            ' Write configuration path
        configurationSheet.Cells(3, n + nbTitleColumns) = template        ' Write configuration Excel template path
        configurationSheet.Cells(4, n + nbTitleColumns) = projectName     ' Write configuration projectName
        configurationSheet.Cells(5, n + nbTitleColumns) = comment         ' Write configuration Comment
        Dim i As Integer
        For i = 1 To moduleCount                         ' For each module
            configurationSheet.Cells(i + nbTitleRows, n + nbTitleColumns) = "-"     ' Set Default path as not initialized
        Next i
        addConfiguration = n
       Else
        addConfiguration = -n
    End If
End Function

Public Function vtkConfigurationManager_addConfiguration(configuration As String, Optional path As String = "", Optional template As String = "", Optional projectName As String = "", Optional comment As String = "") As Integer
    vtkConfigurationManager_addConfiguration = addConfiguration(configuration, path, template, projectName, comment)
End Function

'---------------------------------------------------------------------------------------
' Procedure : configurations
' Author    : Jean-Pierre Imbert
' Date      : 28/08/2013
' Purpose   : Return a collection of initialized vtkConfiguration objects
'---------------------------------------------------------------------------------------
'
Public Function configurations() As Collection
    Dim col As New Collection, i As Integer, c As vtkConfiguration
    For i = 1 To configurationCount
        Set c = New vtkConfiguration
        c.init confManager:=Me, confNumber:=i
        col.Add Item:=c, Key:=configuration(i)
    Next i
    Set configurations = col
End Function

'---------------------------------------------------------------------------------------
' Procedure : getConfigurationNumber
' Author    : Jean-Pierre Imbert
' Date      : 26/05/2013
' Purpose   : return the number of a configuration given its name
'               - return 0 of the name is inexistant
'---------------------------------------------------------------------------------------
'
Public Function getConfigurationNumber(configuration As String) As Integer
    Dim r As Range
    On Error Resume Next
    Set r = configurationSheet.Rows(1)      ' Select first column of the sheet
    Set r = r.Offset(0, nbTitleColumns)     ' Forget the first column
    Set r = r.Find(what:=configuration, SearchOrder:=xlByRows, LookAt:=xlWhole)
    On Error GoTo 0
    If r Is Nothing Then
        getConfigurationNumber = 0
       Else
        getConfigurationNumber = r.Column - nbTitleColumns
    End If
End Function

Public Function vtkConfigurationManager_getConfigurationNumber(configuration As String) As Integer
    vtkConfigurationManager_getConfigurationNumber = getConfigurationNumber(configuration)
End Function

'---------------------------------------------------------------------------------------
' Procedure : getConfigurationPathWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : return the n-th relative configuration path of the project, given n as integer
'               - return "" if the configuration is inexistant
'---------------------------------------------------------------------------------------
'
Public Function getConfigurationPathWithNumber(n As Integer) As String
    Dim sResult As String
    sResult = ""
    If n >= 1 And n <= configurationCount Then
        sResult = configurationSheet.Cells(pathLine, n + nbTitleColumns)
       Else
        sResult = ""
    End If
    getConfigurationPathWithNumber = sResult
End Function

Public Function vtkConfigurationManager_getConfigurationPathWithNumber(n As Integer) As String
    vtkConfigurationManager_getConfigurationPathWithNumber = getConfigurationPathWithNumber(n)
End Function

'---------------------------------------------------------------------------------------
' Procedure : setConfigurationPathWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : change the n-th relative configuration path of the project, given n as integer
'               - does nothing if the configuration is inexistant
'---------------------------------------------------------------------------------------
'
Public Sub setConfigurationPathWithNumber(n As Integer, path As String)
    If n >= 1 And n <= configurationCount Then
        configurationSheet.Cells(pathLine, n + nbTitleColumns) = path
    End If
End Sub

Public Sub vtkConfigurationManager_setConfigurationPathWithNumber(n As Integer, path As String)
    setConfigurationPathWithNumber n, path
End Sub

'---------------------------------------------------------------------------------------
' Function  : getConfigurationPath
' Author    : Jean-Pierre Imbert
' Date      : 26/05/2013
' Purpose   : return the relative path of a configuration given its name
'               - return "" of the name is inexistant
'---------------------------------------------------------------------------------------
'
Public Function getConfigurationPath(configuration As String) As String
    getConfigurationPath = getConfigurationPathWithNumber(getConfigurationNumber(configuration))
End Function

Public Function vtkConfigurationManager_getConfigurationPath(configuration As String) As String
    vtkConfigurationManager_getConfigurationPath = getConfigurationPath(configuration)
End Function

'---------------------------------------------------------------------------------------
' Procedure : setConfigurationPath
' Author    : Jean-Pierre Imbert
' Date      : 26/05/2013
' Purpose   : change the path of a configuration given its name
'---------------------------------------------------------------------------------------
'
Public Sub setConfigurationPath(configuration As String, path As String)
    setConfigurationPathWithNumber n:=getConfigurationNumber(configuration), path:=path
End Sub

Public Sub vtkConfigurationManager_setConfigurationPath(configuration As String, path As String)
    setConfigurationPath configuration, path
End Sub

'---------------------------------------------------------------------------------------
' Procedure : getConfigurationProjectNameWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 08/06/2014
' Purpose   : return the n-th configuration project name of the project, given n as integer
'               - return "" if the configuration is inexistant
'               - return the default project name if
'                   - it is not initialized in the configuration sheet v1.1
'                   - the configuration sheet is v1.0, so there is no project name field
'---------------------------------------------------------------------------------------
'
Public Function getConfigurationProjectNameWithNumber(n As Integer) As String
    Dim sResult As String
    sResult = ""
    If n >= 1 And n <= configurationCount Then
        If m_sheetVersion = currentVersion Then
            sResult = configurationSheet.Cells(projectNameLine, n + nbTitleColumns)
            If sResult = "" Then sResult = defaultProjectNameWithNumber(n)
           Else
            sResult = defaultProjectNameWithNumber(n)
            End If
       Else
        sResult = ""
    End If
    getConfigurationProjectNameWithNumber = sResult
End Function

'---------------------------------------------------------------------------------------
' Procedure : setConfigurationProjectNameWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 08/06/2014
' Purpose   : change the n-th configuration project name of the project, given n as integer
'               - does nothing if the configuration is inexistant
'               - does nothing and return an error if the configuration sheet is v1.0
'---------------------------------------------------------------------------------------
'
Public Sub setConfigurationProjectNameWithNumber(n As Integer, projectName As String)
    If n >= 1 And n <= configurationCount Then
        If m_sheetVersion = currentVersion Then
            configurationSheet.Cells(projectNameLine, n + nbTitleColumns) = projectName
           Else
            Err.Raise VTK_OBSOLETE_CONFIGURATION_SHEET, "vtkConfigurationManagerExcel:setConfigurationProjectNameWithNumber", _
            "Impossible to set a configuration projectName with this configuration sheet version (project=" & m_projectName & ", " & m_sheetVersion & ")"
        End If
    End If
End Sub

'---------------------------------------------------------------------------------------
' Procedure : getConfigurationCommentWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 08/06/2014
' Purpose   : return the n-th configuration comment of the project, given n as integer
'               - return "" if the configuration is inexistant
'               - return the default comment if
'                   - it is not initialized in the configuration sheet v1.1
'                   - the configuration sheet is v1.0, so there is no comment field
'---------------------------------------------------------------------------------------
'
Public Function getConfigurationCommentWithNumber(n As Integer) As String
    Dim sResult As String
    sResult = ""
    If n >= 1 And n <= configurationCount Then
        If m_sheetVersion = currentVersion Then
            sResult = configurationSheet.Cells(commentLine, n + nbTitleColumns)
            If sResult = "" Then sResult = defaultCommentWithNumber(n)
           Else
            sResult = defaultCommentWithNumber(n)
            End If
       Else
        sResult = ""
    End If
    getConfigurationCommentWithNumber = sResult
End Function

'---------------------------------------------------------------------------------------
' Procedure : setConfigurationCommentWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 08/06/2014
' Purpose   : change the n-th configuration comment of the project, given n as integer
'               - does nothing if the configuration is inexistant
'               - does nothing and return an error if the configuration sheet is v1.0
'---------------------------------------------------------------------------------------
'
Public Sub setConfigurationCommentWithNumber(n As Integer, comment As String)
    If n >= 1 And n <= configurationCount Then
        If m_sheetVersion = currentVersion Then
            configurationSheet.Cells(commentLine, n + nbTitleColumns) = comment
           Else
            Err.Raise VTK_OBSOLETE_CONFIGURATION_SHEET, "vtkConfigurationManagerExcel:setConfigurationCommentWithNumber", _
            "Impossible to set a configuration comment with this configuration sheet version (project=" & m_projectName & ", " & m_sheetVersion & ")"
        End If
    End If
End Sub

'---------------------------------------------------------------------------------------
' Procedure : getConfigurationTemplateWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 01/07/2014
' Purpose   : return the n-th configuration Excel template path of the project, given n as integer
'               - return "" if the configuration is inexistant
'               - return the default comment if
'                   - it is not initialized in the configuration sheet v1.1
'                   - the configuration sheet is v1.0, so there is no comment field
'---------------------------------------------------------------------------------------
'
Public Function getConfigurationTemplateWithNumber(n As Integer) As String
    Dim sResult As String
    sResult = ""
    If n >= 1 And n <= configurationCount Then
        If m_sheetVersion = currentVersion Then
            sResult = configurationSheet.Cells(templateLine, n + nbTitleColumns)
            If sResult = "" Then sResult = defaultTemplateWithNumber(n)
           Else
            sResult = defaultTemplateWithNumber(n)
            End If
       Else
        sResult = ""
    End If
    getConfigurationTemplateWithNumber = sResult
End Function

'---------------------------------------------------------------------------------------
' Procedure : setConfigurationTemplateWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 01/07/2014
' Purpose   : change the n-th configuration comment of the project, given n as integer
'               - does nothing if the configuration is inexistant
'               - does nothing and return an error if the configuration sheet is v1.0
'---------------------------------------------------------------------------------------
'
Public Sub setConfigurationTemplateWithNumber(n As Integer, template As String)
    If n >= 1 And n <= configurationCount Then
        If m_sheetVersion = currentVersion Then
            configurationSheet.Cells(templateLine, n + nbTitleColumns) = template
           Else
            Err.Raise VTK_OBSOLETE_CONFIGURATION_SHEET, "vtkConfigurationManagerExcel:setConfigurationTemplateWithNumber", _
            "Impossible to set a configuration template path with this configuration sheet version (project=" & m_projectName & ", " & m_sheetVersion & ")"
        End If
    End If
End Sub

'---------------------------------------------------------------------------------------
' Procedure : getConfigurationReferencesWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 08/06/2014
' Purpose   : return the n-th configuration references collection of the project, given n as integer
'---------------------------------------------------------------------------------------
'
Public Function getConfigurationReferencesWithNumber(n As Integer) As Collection
    Set getConfigurationReferencesWithNumber = referenceManager.references(n)
End Function

'---------------------------------------------------------------------------------------
' Property  : moduleCount as Integer - Read Only - Public
' Author    : Jean-Pierre Imbert
' Date      : 25/05/2013
' Purpose   : Get the number of modules
'---------------------------------------------------------------------------------------
'
Public Property Get moduleCount() As Integer
    ' The number of modules is the number of used rows minus two
    moduleCount = configurationSheet.UsedRange.Rows.Count - nbTitleRows
End Property

Public Property Get vtkConfigurationManager_moduleCount() As Integer
    vtkConfigurationManager_moduleCount = moduleCount()
End Property

'---------------------------------------------------------------------------------------
' Procedure : modules
' Author    : Jean-Pierre Imbert
' Date      : 28/08/2013
' Purpose   : Return a collection of initialized vtkModule objects
'---------------------------------------------------------------------------------------
'
Public Function modules() As Collection
    Dim col As New Collection, i As Integer, m As vtkModule
    For i = 1 To moduleCount
        Set m = New vtkModule
        m.init confManager:=Me, modNumber:=i
        col.Add Item:=m, Key:=module(i)
    Next i
    Set modules = col
End Function
'---------------------------------------------------------------------------------------
' Function  : module
' Author    : Jean-Pierre Imbert
' Date      : 26/05/2013
' Purpose   : return the n-th module of the project, given n as integer
'               - return "" if the module is inexistant
'---------------------------------------------------------------------------------------
'
Public Function module(n As Integer) As String
    Dim sResult As String
    sResult = ""
    If n >= 1 And n <= moduleCount Then
        sResult = configurationSheet.Cells(n + nbTitleRows, 1)
       Else
        sResult = ""
    End If
    module = sResult
End Function

Public Function vtkConfigurationManager_module(n As Integer) As String
    vtkConfigurationManager_module = module(n)
End Function

'---------------------------------------------------------------------------------------
' Procedure : getModuleNumber
' Author    : Jean-Pierre Imbert
' Date      : 26/05/2013
' Purpose   : return the number of a module given its name
'               - return 0 of the name is inexistant
'---------------------------------------------------------------------------------------
'
Public Function getModuleNumber(module As String) As Integer
    Dim r As Range
    On Error Resume Next
    Set r = configurationSheet.Columns(1)   ' Select first column of the sheet
    Set r = r.Offset(nbTitleRows, 0)                  ' Forget the two first rows
    Set r = r.Find(what:=module, SearchOrder:=xlByColumns, LookAt:=xlWhole)
    On Error GoTo 0
    If r Is Nothing Then
        getModuleNumber = 0
       Else
        getModuleNumber = r.Row - nbTitleRows
    End If
End Function

Public Function vtkConfigurationManager_getModuleNumber(module As String) As Integer
    vtkConfigurationManager_getModuleNumber = getModuleNumber(module)
End Function

'---------------------------------------------------------------------------------------
' Procedure : addModule
' Author    : Jean-Pierre Imbert
' Date      : 26/05/2013
' Purpose   : Add a new module given its name
'               - return the number of the added module
'               - if the module is already existant, return minus the number of the existant module
'---------------------------------------------------------------------------------------
'
Public Function addModule(module As String) As Integer
    Dim n As Integer
    n = getModuleNumber(module)
    If n = 0 Then   ' n = 0 means non-existant module
        n = moduleCount + 1                                     ' Set module number
        configurationSheet.Cells(n + nbTitleRows, 1) = module   ' Write module name
        Dim i As Integer
        For i = 1 To configurationCount                         ' For each configuration
            configurationSheet.Cells(n + nbTitleRows, i + nbTitleColumns) = "-"     ' Set Default path as not initialized
        Next i
        addModule = n
       Else
        addModule = -n
    End If
End Function

Public Function vtkConfigurationManager_addModule(module As String) As Integer
    vtkConfigurationManager_addModule = addModule(module)
End Function

'---------------------------------------------------------------------------------------
' Procedure : getModulePathWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 26/05/2013
' Purpose   : Get a module relative path given its module and configuration numbers
'               - return "" if the module or the configuration doesn't exist
'               - return "" if the path is not initialized ("-" in the cell of the configuration sheet)
'---------------------------------------------------------------------------------------
'
Public Function getModulePathWithNumber(numModule As Integer, numConfiguration As Integer) As String
    Dim sResult As String
    If numModule >= 1 And numModule <= moduleCount And numConfiguration >= 1 And numConfiguration <= configurationCount Then
        sResult = configurationSheet.Cells(numModule + nbTitleRows, numConfiguration + nbTitleColumns)
        If sResult = "-" Then sResult = ""
       Else
        sResult = ""
    End If
    getModulePathWithNumber = sResult
End Function

Public Function vtkConfigurationManager_getModulePathWithNumber(numModule As Integer, numConfiguration As Integer) As String
    vtkConfigurationManager_getModulePathWithNumber = getModulePathWithNumber(numModule, numConfiguration)
End Function

'---------------------------------------------------------------------------------------
' Procedure : setModulePathWithNumber
' Author    : Jean-Pierre Imbert
' Date      : 26/05/2013
' Purpose   : Set a module relative path given its module and configuration numbers
'               - if the path given is "", it is replaced by "-" in the configuration sheet cell
'---------------------------------------------------------------------------------------
'
Public Sub setModulePathWithNumber(path As String, numModule As Integer, numConfiguration As Integer)
    Dim s As String
    If numModule >= 1 And numModule <= moduleCount And numConfiguration >= 1 And numConfiguration <= configurationCount Then
        If path = "" Then
            s = "-"
           Else
            s = path
        End If
        configurationSheet.Cells(numModule + nbTitleRows, numConfiguration + nbTitleColumns) = s
    End If
End Sub

Public Sub vtkConfigurationManager_setModulePathWithNumber(path As String, numModule As Integer, numConfiguration As Integer)
    setModulePathWithNumber path, numModule, numConfiguration
End Sub

'---------------------------------------------------------------------------------------
' Procedure : referenceManager, private
' Author    : Jean-Pierre Imbert
' Date      : 19/06/2014
' Purpose   : Return the reference manager associated with the configuration manager
'---------------------------------------------------------------------------------------
'
Private Function referenceManager() As vtkReferenceManager
    initReferences refs:=Nothing
    Set referenceManager = m_refManager
End Function

'---------------------------------------------------------------------------------------
' Procedure : references
' Author    : Jean-Pierre Imbert
' Date      : 19/06/2014
' Purpose   : Return a collection of all vtkReferences objects
'---------------------------------------------------------------------------------------
'
Public Function references() As Collection
    Set references = referenceManager.allReferences
End Function

Public Function vtkConfigurationManager_references() As Collection
    Set vtkConfigurationManager_references = references
End Function

'---------------------------------------------------------------------------------------
' Procedure : initReferences
' Author    : Jean-Pierre Imbert
' Date      : 23/06/2014
' Purpose   : Initialize the references with the collection of vtkReference
'---------------------------------------------------------------------------------------
'
Public Sub initReferences(refs As Collection)
    If m_refManager Is Nothing Then
        Set m_refManager = New vtkReferenceManager
        m_refManager.init Wb:=Workbook, confCount:=Me.configurationCount, nbTitleColumnsInConfSheet:=nbTitleColumns, devConf:=m_devConfiguration, references:=refs
    End If
End Sub

