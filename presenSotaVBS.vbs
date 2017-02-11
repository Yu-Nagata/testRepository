'===========================================================
'TCP/IPで通信するサンプル(VBS/VBA)
'通信オブジェクト生成
'===========================================================
'【注意事項】
'　[regsvr32.exe NONCOMSCK.OCX]が必要
'　このVBSサンプルは64bit(x64)版VBSではCreateObjectエラーになります。
'　32bit(x86)版のWSH(C:\Windows\SysWow64\cscript.exe)を使用してください。
'===========================================================

'===========================================================
'メイン処理
'===========================================================
'----------
' 初期処理／設定
'----------
Dim ipAddess, portNo
Dim i
Dim commandStr(10), k
Dim commandFileName
Dim pptFileName

'ipAddess        = "172.16.168.71"
'portNo          = 5001
ipAddess        = "127.0.0.1"
portNo          = 4000
commandFileName = "presenTxt.txt"
pptFileName     = "Sample.pptx"


'----------
' 処理
'----------
Set Winsock1 = CreateObject("NonComSck.Winsock")
i = 0

'パワポオブジェクト生成・初期設定
Set oApp = CreateObject("PowerPoint.Application")
oApp.Visible = True '可視にする
oApp.Presentations.Open(getCurPath & "\" & pptFileName)
oApp.ActivePresentation.SlideShowSettings.Run 'PPT起動

'コマンド用文字列を配列にセット
Call readCommandFile(getCurPath & "\" & commandFileName)

'コマンド用文字列を送信するループ
Do While True
	Call startConnection
	Call transData
Loop

WSCript.Quit

'===========================================================
'メイン処理
'===========================================================
Sub transData()
	
	Dim wText
	Dim encodeSendStr
	Dim splitAryStr
	Dim wSendStr
	
	WScript.Echo "---transData-----"
	'----------
	' データ送信(文字列をByte配列に変換して送信)／Endの場合は強制終了
	'----------
	
	'コマンド用文字列を１行分だけ抽出
	wText = speechText(i)
	WScript.Echo i & ":" & wText

	'コマンド用文字列（改行コード<LF>込）をUTF-8に変換する
	encodeSendStr = encodeStr(wText & vbLf, "UTF-8")
	
	'コマンド用文字列をカンマで分割する
	'splitAryStr = Split(encodeSendStr, ",")
	
	'wSendStr = splitAryStr(1) & "," & splitAryStr(2)
	'WScript.Echo "SendStr(" & i & "):" & wSendStr
	
	'----------
    ' PPTのページ操作
    '----------
    If i <> 0 Then
    	oApp.SlideShowWindows(1).View.Next 'ページ送り
    End If
	
	'サーバ側へコマンド用文字列を送信
	Winsock1.SEndData encodeSendStr

    i = i + 1

	'----------
	' データ受信（サーバからの受信応答を確認）
	'----------
	Winsock1.Start_EventForScript()
	Do
		WScript.Sleep(500)
		Evt = Winsock1.GetEventParameters()
		If Ubound(Evt) >= 0 Then
		
			' Evt(0) : イベント名
			If Evt(0) = "DataArrival" Then
				' Evt(9) : 受信データのByte配列
				' Byte配列を文字列に変換
				WScript.Echo Winsock1.ByteArrayToStr(Evt(9))
				Exit Do
				
			End If
			
		End If
	Loop
	Winsock1.End_EventForScript()
	
	'１伝文の送受信を確認したら切断（TCP/IP通信の制約）
	Call disConnection()
	
	'終了コマンドが設定されていたら、プログラム終了
	IF wText = "End" THEN
		Call disConnection()
		oApp.ActivePresentation.Application.Quit 'PPTの終了
		WSCript.Quit
	End IF
	
End Sub

'===========================================================
' TCP通信開始
'===========================================================
Sub startConnection()
	WScript.Echo "---startConnection-----"
	'----------
	' TCP/IP接続
	'----------
	Winsock1.Connect ipAddess, portNo

	'----------
	' TCP/IP接続待ち
	'----------
	Do While Winsock1.State = 6
	    WScript.Sleep(500)
	Loop
End Sub

'===========================================================
' TCP通信切断
'===========================================================
Sub disConnection()
	WScript.Echo "---disconnection-----"
	
	Winsock1.Close2
	
End Sub

'===========================================================
' コマンド用文字列の抽出（１件分）
'===========================================================
Function speechText(Byval pSpeechNo) 
	Dim wRetText
	
	wRetText = commandStr(pSpeechNo)
	speechText = wRetText
	
End Function

'===========================================================
' コマンド用ファイル（UTF-8のテキストファイル）を読込む
'===========================================================
Sub readCommandFile(Byval pFileName)
	Dim objStream

	'----------
	' ファイルを読込む
	'----------
	Set objStream = CreateObject("ADODB.Stream")
	
	objStream.Type = 2							' 1：バイナリ, 2：テキスト
	objStream.Charset = "UTF-8"					' 文字コード指定
	objStream.Open
	
	objStream.LoadFromFile pFileName
	
	'----------
	' 読込みファイルから1行ずつコマンド用文字列（配列）に書込み
	'----------
	k = 0
	Do Until objStream.EOS
		commandStr(k) = objStream.ReadText(-2)	' -1：全行読込み, -2：一行読込み
		'WScript.Echo commandStr(k)
		
		k = k + 1
	Loop
	
	'----------
	'終了処理
	'----------
	objStream.Close
	Set objStream = Nothing
	
End Sub

'===========================================================
' 文字コード変換
'===========================================================
Function encodeStr(Byval pStrUni, Byval pCharSet) 

	Set objStream = CreateObject("ADODB.Stream")
	
	'----------
	'指定された文字列をStreamに書込み
	'----------
	objStream.Open
	objStream.Type = 2					' 1：バイナリ, 2：テキスト
	objStream.Charset = pCharSet
	objStream.WriteText pStrUni 
	objStream.Position = 0

	'----------
	'文字コード変換してStremから読み出す
	'----------
	'BOMがある文字コードの場合は、最初のBOM分をスキップ
	objStream.Type = 1					' 1：バイナリ, 2：テキスト
	Select Case UCase(pCharSet)
		Case "UNICODE", "UTF-16"
			objStream.Position = 2
			
		Case "UTF-8"
			objStream.Position = 3
			
	End Select
	
	encodeStr = objStream.Read()
	
	'----------
	'終了処理
	'----------
	objStream.Close
	Set objStream = Nothing
	
End Function

'===========================================================
' カレントパスを取得
'===========================================================
Function getCurPath()
	Dim wFileObj
	
	Set wFileObj = createObject("Scripting.FileSystemObject")
	getCurPath = wFileObj.GetParentFolderName(WScript.ScriptFullName)
	
End Function
