.686
.model flat
public _main

extern _CharUpperA@4 : near
extern _ExitProcess@4 : near
extern _FillConsoleOutputAttribute@20 : near
extern _FillConsoleOutputCharacterA@20 : near
extern _GetConsoleMode@8 : near
extern _GetConsoleScreenBufferInfo@8 : near
extern _GetStdHandle@4 : near
extern _ReadConsoleA@20 : near
extern _SetConsoleCursorPosition@8 : near
extern _SetConsoleMode@8 : near
extern _SetConsoleTitleA@4 : near
extern _WaitForSingleObject@8 : near
extern _WriteConsoleA@20 : near

.data
	; WinAPI constants.
	STD_OUTPUT_HANDLE equ -11
	STD_INPUT_HANDLE equ -10
	INFINITE equ -1

	; Game constants.
	PLAYER1_CHAR equ 'O' ; Make sure this is not a digit character!
	PLAYER2_CHAR equ 'X' ; Make sure this is not a digit character!

	; Console output and input stuff.
	charsWritten dd ?
	consoleMode dd ?
	consoleScreenBufferInfo db 22 dup (?) ; A 22-byte structure.
	consoleSize dd ?
	consoleTitle db "NoCr by ToczaMan", 0
	coordinates dw 0, 0
	inputHandle dd ?
	outputHandle dd ?
		
	; Interface.
	head db "Welcome to NoCr!", 10, "N - toggle field numbers, Q - resign.", 10,  "=====================================", 10, 10, 0
	headLength = $ - head - 1
	grid db ' ', '|', ' ', '|', ' ', 10, ' ', '|', ' ', '|', ' ', 10, ' ', '|', ' ', '|', ' ', 10, 0
	gridSeparator db '-', '|', '-', '|', '-', 10, 0
	gridSeparatorLength = $ - gridSeparator - 1

	; Messages.
	prompt db 10, "Choose your field, player X (1-9): ", 0
	promptLength = $ - prompt - 1
	drawMessage db 10, "The game ended in a draw.", 0
	drawMessageLength = $ - drawMessage - 1
	resignMessage db 10, "Player X has resigned.", 0
	resignMessageLength = $ - resignMessage - 1
	victoryMessage db 10, "Player X has won!", 0
	victoryMessageLength = $ - victoryMessage - 1
	
	; States.
	choice db ?
	playerNumber db 0
	numberOfTurns db 9
	result db 0	

.code
	initConsole proc near
		push dword ptr STD_OUTPUT_HANDLE
		call _GetStdHandle@4
		mov outputHandle, eax
		push dword ptr STD_INPUT_HANDLE
		call _GetStdHandle@4
		mov inputHandle, eax
		push offset consoleTitle
		call _SetConsoleTitleA@4
		ret
	initConsole endp

	clearScreen proc near
		push offset consoleScreenBufferInfo
		push outputHandle
		call _GetConsoleScreenBufferInfo@8
		xor edx, edx
		mov ax, word ptr consoleScreenBufferInfo[0]
		mul word ptr consoleScreenBufferInfo[2]
		shl edx, 16
		mov dx, ax
		mov consoleSize, edx
		push offset charsWritten
		push dword ptr coordinates
		push consoleSize
		push dword ptr 32
		push outputHandle
		call _FillConsoleOutputCharacterA@20
		push offset consoleScreenBufferInfo
		push outputHandle
		call _GetConsoleScreenBufferInfo@8
		push offset charsWritten
		push dword ptr coordinates
		push consoleSize
		push dword ptr consoleScreenBufferInfo[8]
		push outputHandle
		call _FillConsoleOutputAttribute@20
		push dword ptr coordinates
		push outputHandle
		call _SetConsoleCursorPosition@8
		ret
	clearScreen endp

	printHead proc near
		push dword ptr 0
		push offset charsWritten
		push dword ptr headLength
		push offset head
		push outputHandle
		call _WriteConsoleA@20
		ret
	printHead endp

	drawGridLine proc near
		mov edx, [esp + 4]
		push dword ptr 0
		push offset charsWritten
		push dword ptr 6
		push edx
		push outputHandle
		call _WriteConsoleA@20
		ret 4
	drawGridLine endp

	drawSeparator proc near
		push dword ptr 0
		push offset charsWritten
		push dword ptr gridSeparatorLength
		push offset gridSeparator
		push outputHandle
		call _WriteConsoleA@20
		ret
	drawSeparator endp

	drawGrid proc near
		push offset grid[0]
		call drawGridLine
		call drawSeparator
		push offset grid[6]
		call drawGridLine
		call drawSeparator
		push offset grid[12]
		call drawGridLine
		ret
	drawGrid endp

	toggleNumbers proc near
		xor ecx, ecx
	toggleNumbersLoop:
		cmp grid[ecx], ' '
		je setNumber
		cmp grid[ecx], '1'
		jb nextField
		cmp grid[ecx], '9'
		ja nextField
		mov grid[ecx], ' '
		jmp nextField
	setNumber:
		mov grid[ecx], cl
		shr grid[ecx], 1
		inc grid[ecx]
		add grid[ecx], '0'
	nextField:
		add ecx, 2
		cmp ecx, 20
		jne toggleNumbersLoop
		ret
	toggleNumbers endp

	printPrompt proc near
		mov al, playerNumber
		add al, '1'
		mov prompt[27], al
		push dword ptr 0
		push offset charsWritten
		push dword ptr promptLength
		push offset prompt
		push outputHandle
		call _WriteConsoleA@20
		ret
	printPrompt endp

	playerInput proc near
		push offset consoleMode
		push inputHandle
		call _GetConsoleMode@8
		push dword ptr 0
		push inputHandle
		call _SetConsoleMode@8 ; Set the console mode to raw.
		push dword ptr INFINITE
		push inputHandle
		call _WaitForSingleObject@8
		push dword ptr 0
		push offset charsWritten
		push dword ptr 1 ; Read only one character.
		push offset choice
		push inputHandle
		call _ReadConsoleA@20
		push consoleMode
		push inputHandle
		call _SetConsoleMode@8 ; Restore the previous console mode.
		push offset choice
		call _CharUpperA@4 ; Convert the character to uppercase.
		ret
	playerInput endp

	checkInput proc near
		cmp choice, 'Q'
		je checkInputResign
		cmp choice, 'N'
		je checkInputToggle
		cmp choice, '1'
		jb checkInputRetContinue
		cmp choice, '9'
		ja checkInputRetContinue
		sub choice, '0'
		ret
	checkInputResign:
		dec result
		add esp, 8
		jmp finish
	checkInputToggle:
		call toggleNumbers
	checkInputRetContinue:
		add esp, 8
		jmp continue
	checkInput endp

	checkField proc near
		movzx eax, choice
		; The input is converted to match the indexes in the grid's array.
		shl eax, 1
		sub al, 2
		cmp grid[eax], PLAYER1_CHAR
		je fieldOcuppied
		cmp grid[eax], PLAYER2_CHAR
		je fieldOcuppied
		ret
	fieldOcuppied:
		; The field is not empty, so we don't want to return and call the next procedure.
		add esp, 8
		jmp continue		
	checkField endp

	placeCharacter proc near
		mov edx, [esp + 4]
		cmp playerNumber, 0
		je placeNought
		mov grid[edx], PLAYER2_CHAR
		jmp placed
	placeNought:
		mov grid[edx], PLAYER1_CHAR
	placed:
		ret 4
	placeCharacter endp

	playerTurn proc near
		cmp numberOfTurns, 0
		je noTurnsLeft
		call printPrompt
		call playerInput
		call checkInput
		call checkField
		push eax ; Converted field number in EAX.
		call placeCharacter
		ret
	noTurnsLeft:
		add esp, 4
		jmp finish
	playerTurn endp

	checkGameState proc near
		push ebx
		mov ecx, -6
	checkHorizontal:
		add ecx, 6
		cmp ecx, 18
		je continueChecking1
		mov al, grid[ecx]
		cmp al, ' '
		je checkHorizontal
		mov dl, grid[ecx + 2]
		cmp al, dl
		jne checkHorizontal
		mov dl, grid[ecx + 4]
		cmp al, dl
		je changeResult
		jmp checkHorizontal
	continueChecking1:
		mov ecx, -2
	checkVertical:
		add ecx, 2
		cmp ecx, 6
		je checkDiagonal1
		mov al, grid[ecx]
		cmp al, ' '
		je checkVertical
		mov dl, grid[ecx + 6]
		cmp al, dl
		jne checkVertical
		mov dl, grid[ecx + 12]
		cmp al, dl
		je changeResult
		jmp checkVertical
	checkDiagonal1:
		mov al, grid[0]
		cmp al, ' '
		je checkDiagonal2
		mov dl, grid[8]
		cmp al, dl
		jne checkDiagonal2
		mov dl, grid[16]
		cmp al, dl
		je changeResult
	checkDiagonal2:
		mov al, grid[4]
		cmp al, ' '
		je checkGameStateFinish
		mov dl, grid[8]
		cmp al, dl
		jne checkGameStateFinish
		mov dl, grid[12]
		cmp al, dl
		jne checkGameStateFinish
	changeResult:
		inc result
		pop ebx
		add esp, 4
		jmp finish
	checkGameStateFinish:
		pop ebx
		ret
	checkGameState endp

	changePlayer proc near
		dec numberOfTurns
		xor playerNumber, 1
		ret
	changePlayer endp

	printEndMessage proc near
		call clearScreen
		call printHead
		call drawGrid
		mov al, playerNumber
		add al, '1'
		cmp result, 0
		jl printResignMessage
		jg printVictoryMessage
		mov eax, drawMessageLength
		mov edx, offset drawMessage
	printMessage:
		push dword ptr 0
		push offset charsWritten
		push eax
		push edx
		push outputHandle
		call _WriteConsoleA@20
		ret
	printResignMessage:
		mov resignMessage[8], al
		mov eax, resignMessageLength
		mov edx, offset resignMessage
		jmp printMessage
	printVictoryMessage:
		mov victoryMessage[8], al
		mov eax, victoryMessageLength
		mov edx, offset victoryMessage
		jmp printMessage
	printEndMessage endp

	endGame proc near
		push ebp
		sub esp, 4
		mov ebp, esp
		mov dword ptr [ebp], 0a0ah ; Double newline.
		push dword ptr 0
		push offset charsWritten
		push dword ptr 2 ; Only the double newline will be printed.
		push ebp
		push outputHandle
		call _WriteConsoleA@20
		add esp, 8 ; We add 8 instead of 4 to get rid of the CALL address.
		pop ebp
		push dword ptr 0
		call _ExitProcess@4
	endGame endp

	_main:
		call initConsole	
	continue:
		call clearScreen
		call printHead
		call drawGrid
		call playerTurn
		call checkGameState
		call changePlayer
		jmp continue
	finish:
		call printEndMessage
		call endGame
end