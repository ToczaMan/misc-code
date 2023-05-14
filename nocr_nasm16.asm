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
head: db `Welcome to NoCr16 (16-bit version of NoCr)!\nN - toggle field numbers, Q - resign.\n=====================================\n\n`
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
player_number: db 0
number_of_turns: db 9
result: db 0  

section .bss
choice: resb 1

section .text
jmp _start

init_video_mode:
  ; Set text mode
  mov ax, 0x0002
  int 0x10
  ret

clear_screen:
  push bp
  mov bp, sp
  push dx
  push cx
  push ax
  push es
  pushf
  
  ; Clear screen buffer
  mov ax, VIDEO_SEGMENT_ADDR
  mov es, ax
  mov cx, SCREEN_CHARS_NUM
  cld
  mov ax, 0x0720
  rep stosw

  ; Move the cursor to the beginning
  mov ax, 0x0200
  xor bx, bx
  xor dx, dx
  int 0x10

  popf
  pop es
  pop ax
  pop cx
  pop dx
  mov sp, bp
  pop bp
  ret


print_string:
  push bp
  mov bp, sp
  push dx
  push cx
  push bx
  push ax
  mov bx, [bp + 4] ; String address
  mov cx, [bp + 6] ; String length
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
  pop ax
  pop bx
  pop cx
  pop dx
  mov sp, bp
  pop bp
  ret 4


print_head:
  mov ax, head_length
  push ax
  mov ax, head
  push ax
  call print_string
  ret


draw_grid_line:
  push bp
  mov bp, sp
  mov ax, 6
  push ax
  mov ax, [bp + 4]
  push ax
  call print_string
  mov sp, bp
  pop bp
  ret 2


draw_separator:
  push bp
  mov bp, sp
  mov ax, grid_separator_length
  push ax
  mov ax, grid_separator
  push ax
  call print_string
  mov sp, bp
  pop bp
  ret


draw_grid:
  mov ax, grid
  push ax
  call draw_grid_line
  call draw_separator
  mov ax, grid + 6
  push ax
  call draw_grid_line
  call draw_separator
  mov ax, grid + 12
  push ax
  call draw_grid_line
  ret


print_prompt:
  mov al, [player_number]
  add al, '1'
  mov [prompt + 27], al
  mov ax, prompt_length
  push ax
  mov ax, prompt
  push ax
  call print_string
  ret


player_input:
  xor ax, ax
  int 0x16
  cmp al, '9'
  jbe is_digit
  and al, 0x5f ; Convert the letter to uppercase.
is_digit:
  mov [choice], al
  ret


check_input:
  cmp byte [choice], 'Q'
  je check_input_resign
  cmp byte [choice], 'N'
  je check_input_toggle
  cmp byte [choice], '1'
  jb check_input_ret_continue
  cmp byte [choice], '9'
  ja check_input_ret_continue
  sub byte [choice], '0'
  ret
check_input_resign:
  dec byte [result]
  add sp, 4
  jmp finish
check_input_toggle:
  call toggle_numbers
check_input_ret_continue:
  add sp, 4
  jmp continue


check_field:
  xor bx, bx
  mov bl, [choice]
  ; The input is converted to match the indices in the grid's array.
  shl bx, 1
  sub bx, 2
  cmp byte [grid + bx], PLAYER1_CHAR
  je field_ocuppied
  cmp byte [grid + bx], PLAYER2_CHAR
  je field_ocuppied
  ret
field_ocuppied:
  ; The field is not empty, so we don't want to return and call the next procedure.
  add sp, 4
  jmp continue


place_character:
  push bp
  mov bp, sp
  mov bx, [bp + 4]
  cmp byte [player_number], 0
  je place_nought
  mov byte [grid + bx], PLAYER2_CHAR
  jmp placed
place_nought:
  mov byte [grid + bx], PLAYER1_CHAR
placed:
  mov sp, bp
  pop bp
  ret 2


player_turn:
  cmp byte [number_of_turns], 0
  je no_turns_left
  call print_prompt
  call player_input
  call check_input
  call check_field
  push bx ; Converted field number in BX.
  call place_character
  ret
no_turns_left:
  add sp, 2
  jmp finish


check_game_state:
  push bx
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
  je check_game_state_finish
  mov dl, [grid + 8]
  cmp al, dl
  jne check_game_state_finish
  mov dl, [grid + 12]
  cmp al, dl
  jne check_game_state_finish
change_result:
  inc byte [result]
  pop bx
  add sp, 2
  jmp finish
check_game_state_finish:
  pop bx
  ret


toggle_numbers:
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
  inc byte [grid + bx]
  add byte [grid + bx], '0'
next_field:
  add cx, 2
  cmp cx, 20
  jne toggle_numbers_loop
  ret


change_player:
  dec byte [number_of_turns]
  xor byte [player_number], 1
  ret


print_end_message:
  call clear_screen
  call print_head
  call draw_grid
  mov al, [player_number]
  add al, '1'
  cmp byte [result], 0
  jl print_resign_message
  jg print_victory_message
  mov ax, draw_message_length
  mov dx, draw_message
print_message:
  push ax
  push dx
  call print_string
  ret
print_resign_message:
  mov byte [resign_message + 10], al
  mov ax, resign_message_length
  mov dx, resign_message
  jmp print_message
print_victory_message:
  mov byte [victory_message + 10], al
  mov ax, victory_message_length
  mov dx, victory_message
  jmp print_message


end_game:
  mov ax, 2
  push ax
  mov ax, head + 119 ; Double newline
  push ax
  call print_string
  add sp, 2 ; We add 8 instead of 4 to get rid of the CALL address.
  int 0x20


_start:
  call init_video_mode  
continue:
  call clear_screen
  call print_head
  call draw_grid
  call player_turn
  call check_game_state
  call change_player
  jmp continue
finish:
  call print_end_message
  call end_game
