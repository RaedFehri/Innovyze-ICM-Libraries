require "Win32API" 

module WSProgressBar
	extend self # creates both class and module methods

	# STDDEFs
	
	#User32.dll
	#	HWND WINAPI GetActiveWindow(void);
	GetActiveWindow = Win32API.new("User32","GetActiveWindow", [], 'L')
	
	
	#User32.dll
	#	HWND WINAPI FindWindowEx(
	#	  _In_opt_ HWND    hwndParent,
	#	  _In_opt_ HWND    hwndChildAfter,
	#	  _In_opt_ LPCTSTR lpszClass,
	#	  _In_opt_ LPCTSTR lpszWindow
	#	);
	FindWindowEx = Win32API.new("user32", "FindWindowEx", ['L','L','P','P'], 'L') 
	
	#User32.dll
	#	LRESULT WINAPI SendMessage(
	#	  _In_ HWND   hWnd,
	#	  _In_ UINT   Msg,
	#	  _In_ WPARAM wParam,
	#	  _In_ LPARAM lParam
	#	);
	SendMessage = Win32API.new("user32", "SendMessage", ['L','L','L','L'], 'L') 
	
	#User32.dll
	#	HWND WINAPI GetDlgItem(
	#	  _In_opt_ HWND hDlg,
	#	  _In_     int  nIDDlgItem
	#	);
	GetDlgItem = Win32API.new("user32", "GetDlgItem", ['L','I'], 'I')
	
	#User32.dll
	#	BOOL WINAPI SetWindowText(
	#	  _In_     HWND    hWnd,
	#	  _In_opt_ LPCTSTR lpString
	#	);
	SetWindowText = Win32API.new("user32", "SetWindowText", ['L','P'], 'I') 
	
	#User32.dll
	#	HANDLE WINAPI LoadImage(
	#	  _In_opt_ HINSTANCE hinst,
	#	  _In_     LPCTSTR   lpszName,
	#	  _In_     UINT      uType,
	#	  _In_     int       cxDesired,
	#	  _In_     int       cyDesired,
	#	  _In_     UINT      fuLoad
	#	);
	LoadImageA = Win32API.new("user32","LoadImageA",["l","p","l","i","i","l"],"p")
	
	#User32.dll
	#	BOOL WINAPI ShowWindow(
	#	  _In_ HWND hWnd,
	#	  _In_ int  nCmdShow
	#	);
	ShowWindow = Win32API.new("user32","ShowWindow",["l","i"],"i")
	
	#SEND MESSAGE CONSTANTS:
	#Progress bar messages
	WM_USER			= 0x0400
	PBM_SETRANGE    = (WM_USER+1)
	PBM_SETPOS      = (WM_USER+2)
	PBM_DELTAPOS    = (WM_USER+3)
	PBM_SETSTEP     = (WM_USER+4)
	PBM_STEPIT      = (WM_USER+5)
	PBM_SETRANGE32  = (WM_USER+6)
	PBM_GETRANGE    = (WM_USER+7)
	PBM_GETPOS      = (WM_USER+8)
	PBM_SETBARCOLOR = (WM_USER+9)
	
	#Dialog Controls
	STATIC1			= 0x142
	STATIC2			= 0x145	
	
	#Window visibility
	SW_SHOW	= 5
	SW_HIDE	= 0
	
	def initialize()
		self.getInstance()
	end
	
	def getInstance()
		#Get the hwnd of the progress bar window
		@Hwnd = GetActiveWindow.call()
		raise 'Failed to get window handle' if (@Hwnd <= 0) 
		
		# Now find the window handle of progress bar
		@PBHwnd = FindWindowEx.call(@Hwnd,0,"msctls_progress32","") 
		raise 'Failed to get progressbar handle' if (@PBHwnd <= 0)
		
		# Now find the window handle of the status text
		@STHwnd = GetDlgItem.call(@Hwnd,STATIC1) 
		raise 'Failed to get progressbar handle' if (@STHwnd <= 0)
		
		# Now find the window handle of the percentage text
		@PTHwnd = GetDlgItem.call(@Hwnd,STATIC2) 
		raise 'Failed to get progressbar handle' if (@PTHwnd <= 0)
		
		@value = 0
		@message = "Starting..."
		@title = "Please wait..."
	end
	
	def value
		@value = SendMessage.call(@PBHwnd, PBM_GETPOS,0,0)
	end
	
	
	def value=(i)
		@value=i
		SendMessage.call(@PBHwnd, PBM_SETPOS,i,0) 
		SetWindowText.call(@PTHwnd, i.to_s + "%")
	end
	
	def message
		@message
	end
	
	def message=(s)
		@message = s
		SetWindowText.call(@STHwnd,s)
	end
	
	def title
		@title
	end
	
	def title=(s)
		@title = s
		SetWindowText.call(@Hwnd,s)
	end
	
	def hidden
		@hidden
	end
	
	def hidden=(b)
		@hidden=b
		ShowWindow.call(@Hwnd,b ? SW_HIDE : SW_SHOW)
	end
end




