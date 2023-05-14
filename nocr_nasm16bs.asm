cpu 8086

org 0x100

section .data
; %ifndef com_file
; com_file: equ 0 ; If not defined create a boot sector
; %else
; %endif

; Game constants
PLAYER1_CHAR: equ 'O' ; Make sure this is not a digit character!
PLAYER2_CHAR: equ 'X' ; Make sure this is not a digit character!

; Video constants
VIDEO_SEGMENT_ADDR: equ 0xb800
SCREEN_CHARS_NUM: equ 80 * 25
TELETYPE_OUTPUT: equ 0x0e

; Interface
head: db `NoCrBS\nN - toggle field numbers, Q - resign.\n=====================================\n\n`
head_length: equ $ - head
grid: db ` | | \n | | \n | | \n`
grid_separator: db `-|-|-\n`
grid_separator_length: equ $ - grid_separator

; Messages
prompt: db 10, "Choose your field, player X (1-9): "
prompt_length: equ $ - prompt
draw_message: db 10, `\n\nThe game ended in a draw.`
draw_message_length: equ $ - draw_message
resign_message: db 10, `\n\nPlayer X has resigned.`
resign_message_length: equ $ - resign_message
victory_message: db 10, `\n\nPlayer X has won!`
victory_message_length: equ $ - victory_message
  
; States
player_number: db '0'
number_of_turns: db 9
result: db 0  

section .bss
choice: resb 1

section .text
jmp _start

clear_screen:
  ; Clear screen buffer
  mov ax, VIDEO_SEGMENT_ADDR
  mov es, ax
  mov cx, SCREEN_CHARS_NUM
  mov ax, 0x0720
  rep stosw
  ; Move the cursor to the beginning
  mov ax, 0x0200
  xor bx, bx
  xor dx, dx
  int 0x10
  ret


print_string:
  mov ah, TELETYPE_OUTPUT
print_char:
  mov al, [bx] ; Character to write
  inc bx
  push bx
  mov bx, 0x000f ; Page number and foreground color
  cmp al, `\n`
  jne print_char_2
  mov al, `\r`
  int 0x10
  mov al, `\n`
print_char_2:
  int 0x10
  pop bx
  loop print_char
  ret


print_head:
  mov cx, head_length
  mov bx, head
  call print_string
  ret


draw_separator:
  mov cx, grid_separator_length
  mov bx, grid_separator
  call print_string
  ret


draw_grid:
  mov cx, 6
  mov bx, grid
  call print_string
  call draw_separator
  mov cx, 6
  mov bx, grid + 6
  call print_string
  call draw_separator
  mov cx, 6
  mov bx, grid + 12
  call print_string
  ret


_start:
  ; Set text mode
  mov ax, 0x0002
  int 0x10
continue:
  call clear_screen
  call print_head
  call draw_grid

  ; Player turn
  cmp byte [number_of_turns], 0
  je finish
  
  ; Print prompt
  mov al, [player_number]
  mov [prompt + 27], al
  mov cx, prompt_length
  mov bx, prompt
  call print_string
  
  ; Player input
  xor ax, ax
  int 0x16
  cmp al, '9'
  jbe is_digit
  and al, 0x5f ; Convert the letter to uppercase.
is_digit:
  mov [choice], al

  ; Check input
  cmp byte [choice], 'Q'
  je check_input_resign
  cmp byte [choice], 'N'
  je check_input_toggle
  cmp byte [choice], '1'
  jb continue
  cmp byte [choice], '9'
  ja continue
  sub byte [choice], '0'
  jmp check_field
check_input_resign:
  dec byte [result]
  jmp finish
check_input_toggle:
  xor cx, cx
toggle_numbers_loop:
  mov bx, cx
  cmp byte [grid + bx], ' '
  je set_number
  cmp byte [grid + bx], '1'
  jb next_field
  cmp byte [grid + bx], '9'
  ja next_field
  mov byte [grid + bx], ' '
  jmp next_field
set_number:
  mov [grid + bx], cl
  shr byte [grid + bx], 1
  add byte [grid + bx], '1'
next_field:
  add cx, 2
  cmp cx, 20
  jne toggle_numbers_loop

check_field:
  xor bx, bx
  mov bl, [choice]
  ; The input is converted to match the indices in the grid's array.
  shl bx, 1
  sub bx, 2
  cmp byte [grid + bx], PLAYER1_CHAR
  je continue
  cmp byte [grid + bx], PLAYER2_CHAR
  je continue

  ; Place character
  cmp byte [player_number], '0'
  je place_nought
  mov byte [grid + bx], PLAYER2_CHAR
  jmp check_game_state
place_nought:
  mov byte [grid + bx], PLAYER1_CHAR

check_game_state:
  mov bx, -6
check_horizontal:
  add bx, 6
  cmp bx, 18
  je continue_checking_1
  mov al, [grid + bx]
  cmp al, ' '
  je check_horizontal
  mov dl, [grid + bx + 2]
  cmp al, dl
  jne check_horizontal
  mov dl, [grid + bx + 4]
  cmp al, dl
  je change_result
  jmp check_horizontal
continue_checking_1:
  mov bx, -2
check_vertical:
  add bx, 2
  cmp bx, 6
  je check_diagonal_1
  mov al, [grid + bx]
  cmp al, ' '
  je check_vertical
  mov dl, [grid + bx + 6]
  cmp al, dl
  jne check_vertical
  mov dl, [grid + bx + 12]
  cmp al, dl
  je change_result
  jmp check_vertical
check_diagonal_1:
  mov al, [grid + 0]
  cmp al, ' '
  je check_diagonal_2
  mov dl, [grid + 8]
  cmp al, dl
  jne check_diagonal_2
  mov dl, [grid + 16]
  cmp al, dl
  je change_result
check_diagonal_2:
  mov al, [grid + 4]
  cmp al, ' '
  je change_player
  mov dl, [grid + 8]
  cmp al, dl
  jne change_player
  mov dl, [grid + 12]
  cmp al, dl
  jne change_player
change_result:
  inc byte [result]
  jmp finish

change_player:
  dec byte [number_of_turns]
  xor byte [player_number], 1
  
  jmp continue

finish:
  call clear_screen
  call print_head
  call draw_grid
  mov al, [player_number]
  cmp byte [result], 0
  jl print_resign_message
  jg print_victory_message
  mov cx, draw_message_length
  mov bx, draw_message
print_message:
  call print_string
  jmp end
print_resign_message:
  mov byte [resign_message + 10], al
  mov cx, resign_message_length
  mov bx, resign_message
  jmp print_message
print_victory_message:
  mov byte [victory_message + 10], al
  mov cx, victory_message_length
  mov bx, victory_message
  jmp print_message

end:
  mov cx, 2
  mov bx, head + 82 ; Double newline
  call print_string
  int 0x20

