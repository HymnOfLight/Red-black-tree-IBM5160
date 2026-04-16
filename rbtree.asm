; ============================================================================
; Red-Black Tree Implementation for IBM PC/XT 5160 (Intel 8088/8086)
;
; Assembler: NASM
; Format:    DOS .COM executable
; Build:     nasm -f bin -o rbtree.com rbtree.asm
;
; Implements: Insert, Delete, Search, In-order traversal, Tree display
; ============================================================================

BITS 16
ORG  0x0100

; ---------------------------------------------------------------------------
; Node layout (10 bytes per node)
; ---------------------------------------------------------------------------
N_KEY    equ 0                  ; word  - key value
N_LEFT   equ 2                  ; word  - pointer to left child
N_RIGHT  equ 4                  ; word  - pointer to right child
N_PARENT equ 6                  ; word  - pointer to parent
N_COLOR  equ 8                  ; byte  - BLACK(0) or RED(1)
NODE_SZ  equ 10

BLACK    equ 0
RED      equ 1

; ============================================================================
; Entry point
; ============================================================================
    jmp main

; ============================================================================
; Data
; ============================================================================

; NIL sentinel -- always BLACK, self-referencing pointers
nil_node:
    dw 0                        ; key
    dw nil_node                 ; left  -> self
    dw nil_node                 ; right -> self
    dw nil_node                 ; parent-> self
    db BLACK                    ; color
    db 0                        ; pad

root:       dw nil_node         ; tree root pointer
pool_ptr:   dw pool             ; next free byte in memory pool

; Scratch space used by rb_delete
del_x:      dw 0               ; pointer to fixup node x
del_yoc:    db 0               ; y's original color

; --- Display strings (terminated by '$' for DOS fn 09h) ---
str_title:   db 'Red-Black Tree for IBM PC/XT 5160 (8086 ASM)', 13, 10
             db '=============================================', 13, 10, '$'
str_insert:  db 13, 10, 'Inserting: $'
str_inorder: db 13, 10, 'In-order:  $'
str_search:  db 13, 10, 'Search $'
str_found:   db ' -> Found$'
str_nfound:  db ' -> Not found$'
str_delete:  db 13, 10, 'Delete: $'
str_tree:    db 13, 10, 'Tree structure (sideways):', 13, 10, '$'
str_b:       db '(B)$'
str_r:       db '(R)$'
str_indent:  db '    $'
str_done:    db 13, 10, 13, 10, 'All operations completed.', 13, 10, '$'
str_crlf:    db 13, 10, '$'
str_empty:   db '  (empty)', 13, 10, '$'

; --- Test data ---
test_keys:   dw 41, 38, 31, 12, 19, 8, 1, 25, 50, 45
TEST_CNT     equ 10

srch_keys:   dw 19, 99, 50, 7
SRCH_CNT     equ 4

del_keys:    dw 8, 31, 45
DEL_CNT      equ 3

; ============================================================================
;  alloc_node -- allocate a fresh node from the memory pool
;  Output : SI = pointer to new node (color = RED, children/parent = NIL)
;  Clobbers: AX
; ============================================================================
alloc_node:
    mov si, [pool_ptr]
    mov word [si + N_KEY], 0
    mov ax, nil_node
    mov [si + N_LEFT], ax
    mov [si + N_RIGHT], ax
    mov [si + N_PARENT], ax
    mov byte [si + N_COLOR], RED
    mov byte [si + 9], 0
    add word [pool_ptr], NODE_SZ
    ret

; ============================================================================
;  left_rotate -- rotate left around node SI
;  Input : SI = x
; ============================================================================
left_rotate:
    push bx
    push di
    push bp

    mov di, [si + N_RIGHT]          ; y = x.right

    mov bp, [di + N_LEFT]           ; t = y.left
    mov [si + N_RIGHT], bp          ; x.right = t
    cmp bp, nil_node
    je .lr_s1
    mov [bp + N_PARENT], si         ; t.parent = x
.lr_s1:
    mov bx, [si + N_PARENT]         ; p = x.parent
    mov [di + N_PARENT], bx         ; y.parent = p

    cmp bx, nil_node
    jne .lr_noroot
    mov [root], di
    jmp .lr_link
.lr_noroot:
    cmp [bx + N_LEFT], si
    jne .lr_rc
    mov [bx + N_LEFT], di
    jmp .lr_link
.lr_rc:
    mov [bx + N_RIGHT], di
.lr_link:
    mov [di + N_LEFT], si           ; y.left = x
    mov [si + N_PARENT], di         ; x.parent = y

    pop bp
    pop di
    pop bx
    ret

; ============================================================================
;  right_rotate -- rotate right around node SI
;  Input : SI = x
; ============================================================================
right_rotate:
    push bx
    push di
    push bp

    mov di, [si + N_LEFT]           ; y = x.left

    mov bp, [di + N_RIGHT]          ; t = y.right
    mov [si + N_LEFT], bp           ; x.left = t
    cmp bp, nil_node
    je .rr_s1
    mov [bp + N_PARENT], si         ; t.parent = x
.rr_s1:
    mov bx, [si + N_PARENT]         ; p = x.parent
    mov [di + N_PARENT], bx         ; y.parent = p

    cmp bx, nil_node
    jne .rr_noroot
    mov [root], di
    jmp .rr_link
.rr_noroot:
    cmp [bx + N_LEFT], si
    jne .rr_rc
    mov [bx + N_LEFT], di
    jmp .rr_link
.rr_rc:
    mov [bx + N_RIGHT], di
.rr_link:
    mov [di + N_RIGHT], si          ; y.right = x
    mov [si + N_PARENT], di         ; x.parent = y

    pop bp
    pop di
    pop bx
    ret

; ============================================================================
;  rb_insert -- insert a key into the red-black tree
;  Input : AX = key
; ============================================================================
rb_insert:
    push bx
    push cx
    push dx
    push si
    push di

    mov dx, ax                      ; DX = key (preserved across alloc)
    call alloc_node                 ; SI = new node z
    mov [si + N_KEY], dx

    ; --- BST walk to find insertion point ---
    mov di, nil_node                ; y = NIL  (will become parent)
    mov bx, [root]                  ; x = root
.ins_walk:
    cmp bx, nil_node
    je .ins_place
    mov di, bx                      ; y = x
    cmp dx, [bx + N_KEY]
    jl .ins_left
    mov bx, [bx + N_RIGHT]
    jmp .ins_walk
.ins_left:
    mov bx, [bx + N_LEFT]
    jmp .ins_walk

.ins_place:
    mov [si + N_PARENT], di         ; z.parent = y
    cmp di, nil_node
    jne .ins_notempty
    mov [root], si                  ; empty tree -> z is root
    jmp .ins_fix
.ins_notempty:
    cmp dx, [di + N_KEY]
    jl .ins_lchild
    mov [di + N_RIGHT], si
    jmp .ins_fix
.ins_lchild:
    mov [di + N_LEFT], si

.ins_fix:
    call rb_insert_fixup

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

; ============================================================================
;  rb_insert_fixup -- restore RB properties after insertion
;  Input : SI = z (newly inserted RED node)
;  Register map: SI=z  BX=parent  BP=grandparent  DI=uncle
; ============================================================================
rb_insert_fixup:
    push ax
    push bx
    push di
    push bp

.ifix_loop:
    mov bx, [si + N_PARENT]         ; bx = z.parent
    cmp byte [bx + N_COLOR], RED
    jne .ifix_done                   ; parent is black -> done

    mov bp, [bx + N_PARENT]         ; bp = grandparent

    cmp bx, [bp + N_LEFT]
    jne .ifix_right

    ; ---- parent is LEFT child of grandparent ----
    mov di, [bp + N_RIGHT]          ; uncle
    cmp byte [di + N_COLOR], RED
    jne .ifix_lc23

    ; Case 1: uncle is RED  -> recolor and move up
    mov byte [bx + N_COLOR], BLACK
    mov byte [di + N_COLOR], BLACK
    mov byte [bp + N_COLOR], RED
    mov si, bp                      ; z = grandparent
    jmp .ifix_loop

.ifix_lc23:
    cmp si, [bx + N_RIGHT]
    jne .ifix_lc3
    ; Case 2: z is right child -> left-rotate parent, fall into case 3
    mov si, bx
    call left_rotate
    mov bx, [si + N_PARENT]
    mov bp, [bx + N_PARENT]

.ifix_lc3:
    ; Case 3: z is left child -> recolor & right-rotate grandparent
    mov byte [bx + N_COLOR], BLACK
    mov byte [bp + N_COLOR], RED
    push si
    mov si, bp
    call right_rotate
    pop si
    jmp .ifix_loop

.ifix_right:
    ; ---- parent is RIGHT child of grandparent (mirror) ----
    mov di, [bp + N_LEFT]           ; uncle
    cmp byte [di + N_COLOR], RED
    jne .ifix_rc23

    mov byte [bx + N_COLOR], BLACK
    mov byte [di + N_COLOR], BLACK
    mov byte [bp + N_COLOR], RED
    mov si, bp
    jmp .ifix_loop

.ifix_rc23:
    cmp si, [bx + N_LEFT]
    jne .ifix_rc3
    mov si, bx
    call right_rotate
    mov bx, [si + N_PARENT]
    mov bp, [bx + N_PARENT]

.ifix_rc3:
    mov byte [bx + N_COLOR], BLACK
    mov byte [bp + N_COLOR], RED
    push si
    mov si, bp
    call left_rotate
    pop si
    jmp .ifix_loop

.ifix_done:
    mov bx, [root]
    mov byte [bx + N_COLOR], BLACK
    pop bp
    pop di
    pop bx
    pop ax
    ret

; ============================================================================
;  rb_search -- look up a key
;  Input : AX = key
;  Output: SI = node pointer (nil_node if not found)
; ============================================================================
rb_search:
    mov si, [root]
.srch_loop:
    cmp si, nil_node
    je .srch_done
    cmp ax, [si + N_KEY]
    je .srch_done
    jl .srch_left
    mov si, [si + N_RIGHT]
    jmp .srch_loop
.srch_left:
    mov si, [si + N_LEFT]
    jmp .srch_loop
.srch_done:
    ret

; ============================================================================
;  rb_minimum -- find the minimum node in a subtree
;  Input : SI = subtree root
;  Output: SI = minimum node
; ============================================================================
rb_minimum:
    cmp word [si + N_LEFT], nil_node
    je .min_done
    mov si, [si + N_LEFT]
    jmp rb_minimum
.min_done:
    ret

; ============================================================================
;  rb_transplant -- replace subtree u with subtree v
;  Input : SI = u,  DI = v
; ============================================================================
rb_transplant:
    push ax
    push bx

    mov bx, [si + N_PARENT]        ; bx = u.parent
    cmp bx, nil_node
    jne .tp_noroot
    mov [root], di
    jmp .tp_parent
.tp_noroot:
    cmp si, [bx + N_LEFT]
    jne .tp_rc
    mov [bx + N_LEFT], di
    jmp .tp_parent
.tp_rc:
    mov [bx + N_RIGHT], di
.tp_parent:
    mov [di + N_PARENT], bx        ; v.parent = u.parent

    pop bx
    pop ax
    ret

; ============================================================================
;  rb_delete -- delete a node from the tree
;  Input : SI = z (node to remove)
;  Register map: SI=z  BX=y(successor)  BP=temporary address reg
; ============================================================================
rb_delete:
    push ax
    push bx
    push si
    push di
    push bp

    ; y_original_color = z.color  (default, overwritten in two-child case)
    mov al, [si + N_COLOR]
    mov [del_yoc], al

    ; ---- Case 1: z.left == NIL  -> replace z with z.right ----
    cmp word [si + N_LEFT], nil_node
    jne .del_hasleft

    mov bp, [si + N_RIGHT]         ; x = z.right
    mov [del_x], bp
    mov di, bp
    call rb_transplant              ; transplant(z, z.right)
    jmp .del_fixchk

.del_hasleft:
    ; ---- Case 2: z.right == NIL -> replace z with z.left ----
    cmp word [si + N_RIGHT], nil_node
    jne .del_twokids

    mov bp, [si + N_LEFT]          ; x = z.left
    mov [del_x], bp
    mov di, bp
    call rb_transplant              ; transplant(z, z.left)
    jmp .del_fixchk

.del_twokids:
    ; ---- Case 3: two children ----
    ; y = minimum(z.right)   (successor)
    push si                         ; save z
    mov si, [si + N_RIGHT]
    call rb_minimum                 ; SI = y
    mov bx, si                      ; BX = y
    pop si                          ; restore z

    mov al, [bx + N_COLOR]
    mov [del_yoc], al               ; y_original_color = y.color

    mov bp, [bx + N_RIGHT]          ; x = y.right
    mov [del_x], bp

    cmp [bx + N_PARENT], si         ; y.parent == z ?
    jne .del_ynotchild

    ; y IS a direct child of z -> set x.parent = y
    mov [bp + N_PARENT], bx
    jmp .del_common

.del_ynotchild:
    ; y is NOT a direct child -> transplant(y, y.right) first
    push si
    mov si, bx                      ; u = y
    mov di, bp                      ; v = y.right = x
    call rb_transplant
    pop si

    ; y.right = z.right;  z.right.parent = y
    mov bp, [si + N_RIGHT]
    mov [bx + N_RIGHT], bp
    mov [bp + N_PARENT], bx

.del_common:
    ; transplant(z, y)
    mov di, bx                      ; v = y
    call rb_transplant              ; SI still = z = u

    ; y.left = z.left;  z.left.parent = y
    mov bp, [si + N_LEFT]
    mov [bx + N_LEFT], bp
    mov [bp + N_PARENT], bx

    ; y.color = z.color
    mov al, [si + N_COLOR]
    mov [bx + N_COLOR], al

.del_fixchk:
    cmp byte [del_yoc], BLACK
    jne .del_ret
    mov si, [del_x]
    call rb_delete_fixup
.del_ret:
    pop bp
    pop di
    pop si
    pop bx
    pop ax
    ret

; ============================================================================
;  rb_delete_fixup -- restore RB properties after deletion
;  Input : SI = x
;  Register map: SI=x  BX=x.parent  DI=w(sibling)  BP=temp address
; ============================================================================
rb_delete_fixup:
    push ax
    push bx
    push di
    push bp

.dfix_loop:
    cmp si, [root]
    je .dfix_done
    cmp byte [si + N_COLOR], RED
    je .dfix_done

    mov bx, [si + N_PARENT]

    cmp si, [bx + N_LEFT]
    jne .dfix_xright

    ; ======== x is LEFT child ========
    mov di, [bx + N_RIGHT]          ; w = sibling

    ; -- Case 1: w is RED --
    cmp byte [di + N_COLOR], RED
    jne .dfix_lc2
    mov byte [di + N_COLOR], BLACK
    mov byte [bx + N_COLOR], RED
    push si
    mov si, bx
    call left_rotate
    pop si
    mov bx, [si + N_PARENT]         ; refresh
    mov di, [bx + N_RIGHT]

.dfix_lc2:
    ; -- Case 2: both children of w are BLACK --
    mov bp, [di + N_LEFT]
    cmp byte [bp + N_COLOR], BLACK
    jne .dfix_lc34
    mov bp, [di + N_RIGHT]
    cmp byte [bp + N_COLOR], BLACK
    jne .dfix_lc34
    mov byte [di + N_COLOR], RED
    mov si, bx                      ; x = x.parent
    jmp .dfix_loop

.dfix_lc34:
    ; -- Case 3: w.right is BLACK (w.left is RED) --
    mov bp, [di + N_RIGHT]
    cmp byte [bp + N_COLOR], BLACK
    jne .dfix_lc4
    mov bp, [di + N_LEFT]
    mov byte [bp + N_COLOR], BLACK
    mov byte [di + N_COLOR], RED
    push si
    mov si, di
    call right_rotate
    pop si
    mov di, [bx + N_RIGHT]          ; refresh w

.dfix_lc4:
    ; -- Case 4 --
    mov al, [bx + N_COLOR]
    mov [di + N_COLOR], al           ; w.color = parent.color
    mov byte [bx + N_COLOR], BLACK
    mov bp, [di + N_RIGHT]
    mov byte [bp + N_COLOR], BLACK
    push si
    mov si, bx
    call left_rotate
    pop si
    mov si, [root]                   ; x = root  (exit)
    jmp .dfix_loop

.dfix_xright:
    ; ======== x is RIGHT child (mirror) ========
    mov di, [bx + N_LEFT]           ; w = sibling

    cmp byte [di + N_COLOR], RED
    jne .dfix_rc2
    mov byte [di + N_COLOR], BLACK
    mov byte [bx + N_COLOR], RED
    push si
    mov si, bx
    call right_rotate
    pop si
    mov bx, [si + N_PARENT]
    mov di, [bx + N_LEFT]

.dfix_rc2:
    mov bp, [di + N_RIGHT]
    cmp byte [bp + N_COLOR], BLACK
    jne .dfix_rc34
    mov bp, [di + N_LEFT]
    cmp byte [bp + N_COLOR], BLACK
    jne .dfix_rc34
    mov byte [di + N_COLOR], RED
    mov si, bx
    jmp .dfix_loop

.dfix_rc34:
    mov bp, [di + N_LEFT]
    cmp byte [bp + N_COLOR], BLACK
    jne .dfix_rc4
    mov bp, [di + N_RIGHT]
    mov byte [bp + N_COLOR], BLACK
    mov byte [di + N_COLOR], RED
    push si
    mov si, di
    call left_rotate
    pop si
    mov di, [bx + N_LEFT]

.dfix_rc4:
    mov al, [bx + N_COLOR]
    mov [di + N_COLOR], al
    mov byte [bx + N_COLOR], BLACK
    mov bp, [di + N_LEFT]
    mov byte [bp + N_COLOR], BLACK
    push si
    mov si, bx
    call right_rotate
    pop si
    mov si, [root]
    jmp .dfix_loop

.dfix_done:
    mov byte [si + N_COLOR], BLACK
    pop bp
    pop di
    pop bx
    pop ax
    ret

; ============================================================================
;  print_tree -- sideways tree display  (reverse in-order: right, node, left)
;  Input : SI = node,  CX = depth (indentation level)
; ============================================================================
print_tree:
    cmp si, nil_node
    je .pt_ret

    push si
    push cx
    push di

    mov di, si                       ; DI = current node

    ; ---- recurse into right subtree ----
    mov si, [di + N_RIGHT]
    inc cx
    call print_tree
    dec cx

    ; ---- print indentation ----
    push cx
.pt_pad:
    test cx, cx
    jz .pt_pad_end
    push cx
    mov dx, str_indent
    mov ah, 09h
    int 21h
    pop cx
    dec cx
    jmp .pt_pad
.pt_pad_end:
    pop cx

    ; ---- print key ----
    mov ax, [di + N_KEY]
    call print_num

    ; ---- print color tag ----
    cmp byte [di + N_COLOR], RED
    jne .pt_blk
    mov dx, str_r
    jmp .pt_clr
.pt_blk:
    mov dx, str_b
.pt_clr:
    mov ah, 09h
    int 21h

    ; ---- newline ----
    mov dx, str_crlf
    mov ah, 09h
    int 21h

    ; ---- recurse into left subtree ----
    mov si, [di + N_LEFT]
    inc cx
    call print_tree

    pop di
    pop cx
    pop si
.pt_ret:
    ret

; ============================================================================
;  inorder -- in-order traversal, prints "key{B|R} " for each node
;  Input : SI = subtree root
; ============================================================================
inorder:
    cmp si, nil_node
    je .io_ret

    push si
    push di

    mov di, si

    mov si, [di + N_LEFT]
    call inorder

    mov ax, [di + N_KEY]
    call print_num

    cmp byte [di + N_COLOR], RED
    jne .io_blk
    mov dl, 'R'
    jmp .io_c
.io_blk:
    mov dl, 'B'
.io_c:
    mov ah, 02h
    int 21h
    mov dl, ' '
    mov ah, 02h
    int 21h

    mov si, [di + N_RIGHT]
    call inorder

    pop di
    pop si
.io_ret:
    ret

; ============================================================================
;  print_num -- print unsigned 16-bit decimal number
;  Input : AX = number
;  Preserves all registers
; ============================================================================
print_num:
    push ax
    push bx
    push cx
    push dx

    mov bx, 10
    xor cx, cx
.pn_div:
    xor dx, dx
    div bx                          ; AX = quotient, DX = remainder
    push dx
    inc cx
    test ax, ax
    jnz .pn_div
.pn_out:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop .pn_out

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================================
; Main program -- demo / test harness
; ============================================================================
main:
    ; ---- Title ----
    mov dx, str_title
    mov ah, 09h
    int 21h

    ; ---- Insert test keys ----
    mov dx, str_insert
    mov ah, 09h
    int 21h

    mov di, test_keys
    mov cx, TEST_CNT
.m_ins:
    test cx, cx
    jz .m_ins_end
    push cx
    push di

    mov ax, [di]
    call print_num
    mov dl, ' '
    mov ah, 02h
    int 21h
    mov ax, [di]                    ; reload (AH was clobbered)
    call rb_insert

    pop di
    pop cx
    add di, 2
    dec cx
    jmp .m_ins
.m_ins_end:

    ; ---- Display tree ----
    mov dx, str_tree
    mov ah, 09h
    int 21h
    mov si, [root]
    cmp si, nil_node
    jne .m_show1
    mov dx, str_empty
    mov ah, 09h
    int 21h
    jmp .m_io1
.m_show1:
    xor cx, cx
    call print_tree

.m_io1:
    mov dx, str_inorder
    mov ah, 09h
    int 21h
    mov si, [root]
    call inorder

    ; ---- Search tests ----
    mov di, srch_keys
    mov cx, SRCH_CNT
.m_srch:
    test cx, cx
    jz .m_srch_end
    push cx
    push di

    mov dx, str_search
    mov ah, 09h
    int 21h

    mov ax, [di]
    call print_num                  ; print key (AX preserved)
    call rb_search                  ; SI = result

    cmp si, nil_node
    je .m_nf
    mov dx, str_found
    jmp .m_sf
.m_nf:
    mov dx, str_nfound
.m_sf:
    mov ah, 09h
    int 21h

    pop di
    pop cx
    add di, 2
    dec cx
    jmp .m_srch
.m_srch_end:

    ; ---- Delete tests ----
    mov di, del_keys
    mov cx, DEL_CNT
.m_del:
    test cx, cx
    jz .m_del_end
    push cx
    push di

    mov dx, str_delete
    mov ah, 09h
    int 21h

    mov ax, [di]
    call print_num
    call rb_search

    cmp si, nil_node
    je .m_dskip
    call rb_delete
.m_dskip:
    pop di
    pop cx
    add di, 2
    dec cx
    jmp .m_del
.m_del_end:

    ; ---- Display tree after deletions ----
    mov dx, str_tree
    mov ah, 09h
    int 21h
    mov si, [root]
    cmp si, nil_node
    jne .m_show2
    mov dx, str_empty
    mov ah, 09h
    int 21h
    jmp .m_io2
.m_show2:
    xor cx, cx
    call print_tree

.m_io2:
    mov dx, str_inorder
    mov ah, 09h
    int 21h
    mov si, [root]
    call inorder

    ; ---- Exit ----
    mov dx, str_done
    mov ah, 09h
    int 21h

    mov ax, 4C00h
    int 21h

; ============================================================================
; Memory pool  (must be last -- grows upward)
; ============================================================================
pool:
