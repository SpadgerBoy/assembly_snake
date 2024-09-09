.386 
.model flat,stdcall 
option casemap:none 

include windows.inc
include user32.inc
include kernel32.inc
include gdi32.inc
include shell32.inc
include comctl32.inc
include comdlg32.inc
include	masm32.inc

includelib user32.lib
includelib kernel32.lib
includelib gdi32.lib
includelib shell32.lib
includelib comctl32.lib
includelib comdlg32.lib
includelib	msvcrt.lib
includelib	masm32.lib

;��������
ClearGame   proto
EndGame     proto
Random      proto Range:DWORD
TimeProc1   proto hWnd:HWND,uMsg:UINT,idEvent :UINT,dwTime:DWORD,wParam:WPARAM
TimeProc2   proto hWnd:HWND,uMsg:UINT,idEvent:UINT,dwTime:DWORD 
KeyDownProc proto dwKey :DWORD

.data
food               dd 20       ;�Ƕ�����
wall                dd 5        ;�ϰ������
dlgsize          dd 400      ;���ڴ�С ��������ʼ����
dlgsize_max     dd 400      ;�������ֵ
mapsize         dd 50       ;��ͼ��
mapsize_max     dd 2500     ;��ͼ�����ֵ
mapsize2        dd 50*50    ;��ͼ��С


AppName			db '̰����',0
success         db '��ϲͨ�����ؿ�',0
Map_dup           db 50*50  dup(0)    ;��Ϸ��ͼ
g_sMsgGamePause db '��Ϸ��ͣ',0
g_sMsgEndGame  db '��Ϸ����',0
FmtStrNodeCount db '��ǰ�÷֣� %d',0
ShowTimer       db '��ǰ��ʱ�� %d.%d��',0

ClassName		db 'DLGCLASS',0
MenuName		db 'MyMenu',0
DlgName			db 'MyDialog',0
sbParts         dd 3            ;�ײ���Ϊ����
sbWidths        dd 0,200,405,0  ;�ײ����ݵĳ���
TIMER1_INTERVAL dd 100          ;ÿ100msˢ��һ��ҳ��
time_ms         dw 0
time_mul        db 10
time_s1         db 0
time_s2         db 0
flag            dd 0

.const 
;���ڵ�ͼ�꣬ico
IDI_ICON			equ	201
IDM_FILE_EXIT		equ 10001   
IDM_NEWGAME			equ 10002   
IDC_SBR1			equ 1001    
BM_BMP				equ 1000    
BM_WALL             equ 1002   

;�ٶȴ�С
ID_GAMESPEED_FAST   equ 333     
ID_GAMESPEED_MIDDLE equ 444     
ID_GAMESPEED_SLOW   equ 555     
;���ڴ�С
ID_MAP_SMALL        equ 70
ID_MAP_MIDDLE       equ 71
ID_MAP_BIG          equ 72
;�ϰ������
ID_NUM1 equ 11
ID_NUM2 equ 12
ID_NUM3 equ 13
;�������
DR_LEFT   equ  0        
DR_RIGHT  equ  1        
DR_UP     equ  2        
DR_DOWN   equ  3        
;��Ϸ״̬
GS_START   equ 1         ;��Ϸ̬Ϊ1
GS_PAUSE  equ 2         ;��̬ͣ
GS_END    equ 3         ;��ֹ̬

TIMER1_ID equ 1000      ;��ʱ�����
TIMER2_ID equ 1001      
TIMER2_INTERVAL equ 1000    ;��ʱ��������������룩

MAP_NONE  equ 0
MAP_FOOD  equ 2
MAP_NODE  equ 3
MAP_WALL  equ 4

.data?
hInstance           HINSTANCE ?
CommandLine         LPSTR ?
handle_Wnd				dd ?        ;���ھ����
handle_Dc               dd ?        ;�豸�����Ļ����ľ��
handle_ImgDc            dd ?        ;�洢��handle_Dc���ݵ��ڴ��豸�����Ļ�����DC��
handle_ImgBmp           dd ?        ;�洢λͼ��Դ
handle_ImgwallDc        dd ?        ;
handle_ImgwallBmp       dd ?        ;
handle_BackDc           dd ?        ;
handle_BackBmp          dd ?        ;
handle_Pen              dd ?        ;���ʵľ��
handle_Brush            dd ?        ;ˢ�ӵľ��

SnakeHead    dd ?        ; ��ͷ
SnakeTail    dd ?        ; ��β
SnakeDirect  dd ?        ; Left Right up down
NodeCount    dd ?              ;��¼�÷�

GameState         dd ?        
RandomSeed        dd ?

stringBuf          db 300 dup(?)  ; String Buffer
timeBuf         db 300 dup(?)   ;��¼��Ϸ��ʱ

SNode struct
    pPrev   dd ?        ; Base
    x       dd ?        ; Base + 4  
    y       dd ?        ; Base + 8
    pNext   dd ?        ; Base + 12
SNode ends


.code 
start: 
 
 
;����ͼ���ӳ���
DrawMap proc                                 
    LOCAL x,y :DWORD                             ;ע���ͼ�ĵף���ʵ�Ѿ�������
    LOCAL i,j :DWORD                             ;����ӳ�������ڵ��ϻ��ϡ����ӡ��͡��ߡ�
    LOCAL Pos :DWORD
    LOCAL pNode :DWORD

    invoke Rectangle,handle_BackDc,0,0,dlgsize ,dlgsize
  
    mov j, 0             ;j���У���=0
    mov Pos, 0           ;��Ե�����
@@1:
    mov i, 0             ;i���У�=0
@@2:   
    mov ebx ,offset Map_dup 
    add ebx,Pos
    mov al,byte ptr [ebx]
    
    ;������ÿ����ռ8x8�����ص�
    .if al == MAP_FOOD          ;���Ƕ���MAP_FOOD
        mov eax, i
        shl eax,3               ;����3λ�� i*8
        mov x , eax
        mov eax ,j
        shl eax ,3              ;����3λ�� j*8
        mov y,eax
        invoke BitBlt,handle_BackDc,x,y,8,8,handle_ImgDc,8,0,SRCCOPY
        
    .elseif al==MAP_WALL        ;��ǽ
        mov eax, i
        shl eax,3 
        mov x , eax
        mov eax ,j
        shl eax ,3
        mov y,eax
        invoke BitBlt,handle_BackDc,x,y,8,8,handle_ImgwallDc,0,0,SRCCOPY
    .endif
    
    mov ecx,mapsize
    inc i               ;i++
    inc Pos             ;Pos++
    cmp i,ecx           ;����һ�У�����ѭ��
    jnz @@2             ;jump if not zero,�����Ϊ0����ת
    
    inc j               ;һ���꣬�м�1
    cmp j,ecx            ;��û���յ㣬����ѭ��
    jnz @@1
      
    ;����
    mov ebx , SnakeHead    ;��ͷ                
@@3:
    cmp ebx , NULL
    jz  @@Break         ;ebx=0ʱ����������
    mov pNode ,ebx      ;������ͷ��ֵ  
    mov eax ,[ebx+4]    ;x
    shl eax , 3         ;x*8
    mov x,eax
    mov eax, [ebx+8]    ;y*8
    shl eax,3
    mov y,eax
    mov eax ,[ebx+12]   ;next
    mov pNode ,eax      ;
    invoke BitBlt,handle_BackDc,x,y,8,8,handle_ImgDc,0,0,SRCCOPY
    
    mov ebx,pNode
    jmp @@3

@@Break:
    ret

DrawMap endp


;��ʼ����Ϸ
NewGame proc 
    local pNode:dword ; the last node
    local x2:dword
    local y2:dword

    invoke ClearGame     ;����Ϸ��ʼǰ���ǰ�����Ϸ

    ; ��ʼʱ������5���ڵ�
;***************************************************************
    ;ͷ���
    invoke LocalAlloc,LPTR,sizeof(SNode)  ;�Ӿֲ����з����ڴ湩����ʹ�ã����������ͷ��λ��
    .if eax == NULL 
        invoke MessageBox,handle_Wnd,addr AppName,addr AppName,MB_OK
    .endif
    mov SnakeHead , eax
    mov pNode ,eax
    mov ebx ,eax
    mov eax , NULL
    mov [ebx],eax   ; SnakeHead.pPrev = null����ǰ�ڵ��ǰһ���ڵ�Ϊ��
    mov eax, 5
    mov [ebx+4],eax ; SnakeHead.x = 5
    mov eax,0
    mov [ebx+8],eax ; SnakeHead.y = 0     ;��Ϸ��ʼʱ��ͷ��λ�ã�5��0��
    mov edi,OFFSET Map_dup
    add edi,5
    mov BYTE PTR[edi],MAP_NODE

    ;��2���ڵ�
    invoke LocalAlloc,LPTR,sizeof(SNode) 
    mov [ebx+12],eax
    mov ebx , eax
    mov eax , pNode
    mov [ebx],eax           ; NextNode.pPrev = pNode
    mov eax , 4
    mov [ebx+4],eax         ; x = 4
    mov eax , 0
    mov [ebx+8],eax         ; y = 0
    mov pNode , ebx
    mov edi,OFFSET Map_dup
    add edi,4
    mov BYTE PTR[edi],MAP_NODE

    ;��3���ڵ�
    invoke LocalAlloc ,LPTR,sizeof(SNode)
    mov [ebx+12],eax
    mov ebx,eax
    mov eax,pNode
    mov [ebx],eax
    mov eax,3
    mov [ebx+4],eax
    mov eax,0
    mov [ebx+8],eax
    mov pNode,ebx
    mov edi,OFFSET Map_dup
    add edi,3
    mov BYTE PTR[edi],MAP_NODE
    
    ;��4���ڵ�
    invoke LocalAlloc ,LPTR,sizeof(SNode)
    mov [ebx+12],eax
    mov ebx,eax
    mov eax,pNode
    mov [ebx],eax
    mov eax,2
    mov [ebx+4],eax
    mov eax,0
    mov [ebx+8],eax
    mov pNode,ebx 
    mov edi,OFFSET Map_dup
    add edi,2
    mov BYTE PTR[edi],MAP_NODE   
    
    ;��5���ڵ�
    invoke LocalAlloc ,LPTR,sizeof(SNode)
    mov [ebx+12],eax
    mov ebx,eax
    mov eax,pNode
    mov [ebx],eax
    mov eax,1
    mov [ebx+4],eax
    mov eax,0
    mov [ebx+8],eax
    mov eax,NULL
    mov [ebx+12],eax
    mov edi,OFFSET Map_dup
    add edi,1
    mov BYTE PTR[edi],MAP_NODE
    
    push ebx
    pop  SnakeTail
    
    push 0
    pop  NodeCount
        
    mov ecx,wall
L5:  
     push ecx
L4:
    invoke Random,mapsize
    mov x2,eax
    invoke Random,mapsize
    mov y2,eax
    mov edx,mapsize
    mul edx
    add eax,x2
    mov ebx,OFFSET Map_dup
    add ebx,eax
    mov al,BYTE PTR [ebx]
    cmp al,  MAP_NONE           ;�Ƚ�ָ��, MAP_NONE=0
    jne L4                      ;ZF=0ʱ��ת��L4
    mov BYTE PTR[ebx],MAP_WALL  
    pop ecx
    loop L5
    
    invoke DrawMap                 ;����ͼ���ӳ���
    invoke BitBlt,handle_Dc,0,0,dlgsize_max,dlgsize_max,NULL,0,0,WHITENESS
    invoke BitBlt,handle_Dc,0,0,dlgsize,dlgsize,handle_BackDc,0,0,SRCCOPY
    
    push DR_RIGHT
    pop  SnakeDirect    
    push GS_START
    pop  GameState
    invoke SetTimer,handle_Wnd,TIMER1_ID,TIMER1_INTERVAL,addr TimeProc1     
    invoke SetTimer,handle_Wnd,TIMER2_ID,TIMER2_INTERVAL,addr TimeProc2

    ret
NewGame endp


;��Ϸ����
EndGame proc
    push GS_END
    pop  GameState
    invoke KillTimer,handle_Wnd,TIMER2_ID       ;�ض�ʱ��2
    invoke KillTimer,handle_Wnd,TIMER1_ID       ;�ض�ʱ��1
    invoke MessageBox,handle_Wnd,addr g_sMsgEndGame,addr AppName,MB_ICONINFORMATION    ;��ʾ������Ϣ��
    ret
EndGame endp


;��ʼ����Ϸʱ���֮ǰ����Դ
ClearGame proc                                  
    LOCAL pNode :DWORD
    .if SnakeHead == NULL
        ret
    .endif

    ;�����Ϸʱ��
    mov time_ms,0
    
    ;�رռ�ʱ��
    invoke KillTimer,handle_Wnd,TIMER1_ID          ;�ͷŶ�ʱ��1
    invoke KillTimer,handle_Wnd,TIMER2_ID          ;�ͷŶ�ʱ��2
     
    ;��յ�ͼ
    invoke RtlZeroMemory,addr Map_dup,mapsize2
    
    ;�����
    mov ebx , SnakeHead
    mov eax ,[ebx+12] ;pNext
    mov pNode ,eax
    
@@1:    
    invoke LocalFree, ebx  ; free mem
    mov ebx,pNode
    cmp ebx,NULL
    jz @@Break
    mov eax,[ebx+12]; pNext
    mov pNode ,eax
    jmp @@1

@@Break: 
    mov eax, NULL
    mov SnakeHead ,eax
    mov SnakeTail ,eax
    push 0
    pop  NodeCount
    push GS_END
    pop  GameState    
    ret

ClearGame endp


;��������������ڸ����ϰ����ʳ��
Random proc Range:DWORD               
    mov eax, RandomSeed
    mov ecx, 23
    mul ecx
    add eax, 7
    and eax, 0FFFFFFFFh
    ror eax, 1              ;ѭ�����ƣ���С����
    xor eax, RandomSeed
    mov RandomSeed, eax
    mov ecx, Range
    xor edx, edx            ;edx����
    div ecx                 ;��������edx:eax�У�����eax�У�������edx�У�edx�������㣬�ʱ���������eax�е�����
    mov eax, edx
    ret
Random endp


;���µ�ͼҳ�棬��ʾ�ߵ�λ��
TimeProc1 proc hWnd:HWND,uMsg:UINT,idEvent :UINT,dwTime:DWORD,wParam:WPARAM
    LOCAL pNode:DWORD                             ;������ʹ����ǰ�ƶ�
    LOCAL Pos:DWORD
    LOCAL x1,y1:DWORD

    pushad                                       ;�������мĴ���
    invoke KillTimer,handle_Wnd,TIMER1_ID            ;�ض�ʱ��
    
    mov ebx , SnakeHead   
    mov eax,[ebx+4]
    mov x1,eax
    mov eax,[ebx+8]
    mov y1,eax
    mov eax, SnakeDirect
    mov ecx,mapsize
    .if eax == DR_LEFT                   ;��������,�Ͱ�ͷ����-1
        dec x1
        cmp x1,0
        jge @@1
        invoke EndGame                  ;����ͼ��Ե��Ϸ����
        popad
        ret
    .elseif (eax==DR_RIGHT)
        inc x1
        cmp x1,ecx
        jle @@1
        invoke EndGame
        popad
        ret
    .elseif(eax==DR_UP)
        dec y1
        cmp y1,0
        jge @@1
        invoke EndGame
        popad
        ret
    .elseif(eax==DR_DOWN)
        inc y1
        cmp y1,ecx
        jle @@1
        invoke EndGame
        popad
        ret
    .endif

@@1:
    mov eax,y1
    mov ecx,mapsize
    mul ecx
    add eax,x1
    mov ebx,OFFSET Map_dup
    add ebx,eax
    mov Pos,ebx
    mov al, BYTE PTR[ebx]
   .if(al==MAP_FOOD)                         ;�Ե��Ƕ�
        inc NodeCount                      ;��¼�÷֣�NodeCount++
        invoke wsprintf,addr stringBuf, addr FmtStrNodeCount,NodeCount ;���ΪstringBuf������ΪFmtStrNodeCount,NodeCount 
        invoke SendDlgItemMessage,handle_Wnd,IDC_SBR1,SB_SETTEXT,2,addr stringBuf ;����Ϣ������Ի���
        mov esi,SnakeHead
        invoke LocalAlloc ,LPTR,sizeof(SNode)
        mov SnakeHead,eax
        mov edi,eax
        mov pNode,eax
        mov [esi],eax
        mov eax,esi
        mov [edi+12],eax                      ;��һ����ǰһ�����Ӻ�
        mov eax,NULL
        mov [edi],eax 
        mov al,MAP_NODE                       
        mov eax,Pos
        mov BYTE PTR[eax],al 
        invoke SetTimer,handle_Wnd,TIMER2_ID,TIMER2_INTERVAL,addr TimeProc2         ;ÿ1���ڵ�ͼ�Ϸ�һ����
        jmp L
    .elseif(al==MAP_NONE)
        jmp L3
    .elseif(al==MAP_NODE)                  ;ҧ���Լ�ʱ����
        invoke EndGame
        popad
        ret
    .elseif(al==MAP_WALL)                   ;ײ���ϰ���ʱֹͣ
        invoke EndGame
        popad
        ret
   .endif 
    
L3:       
    mov eax,SnakeTail
    mov pNode,eax
   
    mov ebx,[eax+4]
    mov eax,[eax+8]
    mov ecx,mapsize
    mul ecx
    add eax,ebx
    mov ebx,OFFSET Map_dup
    add eax,ebx
    mov BYTE PTR[eax],MAP_NONE
   .while(1)
        mov eax,pNode
        mov esi,[eax]
        .if(esi==NULL)
            jmp L
        .endif
        mov ebx,[esi+4]
        mov [eax+4],ebx
        mov ebx,[esi+8]
        mov [eax+8],ebx
        mov edx,[eax+8]
        mov pNode,esi
   .endw 
  
L:  
    mov ebx,x1
    mov eax,pNode
    mov [eax+4],ebx
    mov ebx,y1
    mov [eax+8],ebx
    mov eax,y1
    mov ecx,mapsize
    mul ecx
    add eax,x1
    mov ebx,OFFSET Map_dup
    add ebx,eax
    mov al,MAP_NODE
    mov byte PTR[ebx],al
    invoke DrawMap 
    invoke BitBlt,handle_Dc,0,0,dlgsize,dlgsize,handle_BackDc,0,0,SRCCOPY

    ;��¼ʱ��
    inc time_ms                      
    mov AX,time_ms
    mov BL,time_mul
    idiv BL
    mov time_s1,AL
    mov time_s2,AH
    invoke wsprintf,addr timeBuf, addr ShowTimer,time_s1,time_s2 
    invoke SendDlgItemMessage,handle_Wnd,IDC_SBR1,SB_SETTEXT,1,addr timeBuf ;����Ϣ������Ի���

     mov eax,GameState
    .if eax == GS_PAUSE
        mov eax,flag
        .if eax==0
            invoke MessageBox,handle_Wnd,addr g_sMsgGamePause,addr AppName,MB_ICONINFORMATION    ;��ʾ��ͣ��Ϣ��
            mov flag,1
        .endif
    .endif
    mov eax,food
    .if(eax == NodeCount)
        push GS_END
        pop  GameState
        invoke KillTimer,handle_Wnd,TIMER2_ID       ;�ض�ʱ��2
        invoke KillTimer,handle_Wnd,TIMER1_ID       ;�ض�ʱ��1
        invoke MessageBox,handle_Wnd,addr success,addr AppName,MB_ICONINFORMATION
    .endif 
    mov eax,flag
    .if eax==0
        invoke SetTimer,handle_Wnd,TIMER1_ID,TIMER1_INTERVAL,addr TimeProc1    ;ÿxx��ˢ��һ��
    .endif

    popad                                                             ;�ָ����мĴ���
    ret    
TimeProc1 endp

;�������ʳ��
TimeProc2 proc hWnd:HWND,uMsg:UINT,idEvent:UINT,dwTime:DWORD   
    LOCAL x,y:DWORD
    LOCAL Pos:DWORD
    pushad
L1:
    invoke Random,mapsize
    mov x,eax
    invoke Random,mapsize
    mov y,eax
    mov ecx,mapsize
    mul ecx
    add eax,x
    mov Pos,eax
    mov ebx,OFFSET Map_dup
    add eax,ebx
    mov al,byte ptr [eax]
    .if(al!=0)
        jmp L1
    .else
        jmp L2
    .endif

L2:
    mov ebx,offset Map_dup         ;�������0�Ļ����Ϳ��ԷŶ�
    add ebx,Pos                  ;����Ĵ�����ǷŶ�
    mov al ,MAP_FOOD             
    mov byte ptr [ebx],al
    invoke KillTimer,handle_Wnd,TIMER2_ID  
    invoke DrawMap             
    invoke BitBlt,handle_Dc,0,0,dlgsize,dlgsize,handle_BackDc,0,0,SRCCOPY
    popad  
    ret
TimeProc2 endp

;�������룬�˶�����
KeyDownProc proc dwKey :DWORD

    .if GameState == GS_END           ;GS_END=3,��Ϸ������
        ret
    .elseif GameState == GS_PAUSE     ;GS_PAUSE =2,��̬ͣ�����S������ʼ
        mov eax,dwKey
        .if eax == VK_S                 ;�����S(START)��������ʼ
            push GS_START
            pop  GameState
            mov flag,0
            invoke SetTimer,handle_Wnd,TIMER1_ID,TIMER1_INTERVAL,addr TimeProc1    ;ÿxx��ˢ��һ��
        .endif
        ret
    .elseif GameState == GS_START     ;GS_START=1����Ϸ̬�����������ϡ��¡����ҡ���ͣ
        mov eax,dwKey
        .if eax == VK_UP                 ;�������
            .if SnakeDirect != DR_DOWN      ;��ͷ���������µģ�
                push DR_UP
                pop  SnakeDirect            
            .endif
        .elseif eax == VK_DOWN            
            .if SnakeDirect != DR_UP         
                push DR_DOWN
                pop  SnakeDirect             
            .endif   
        .elseif eax == VK_LEFT            
            .if SnakeDirect != DR_RIGHT      
                push DR_LEFT
                pop  SnakeDirect             
            .endif
        .elseif eax == VK_RIGHT           
            .if SnakeDirect != DR_LEFT       
                push DR_RIGHT
                pop  SnakeDirect             
            .endif    
        .elseif eax == VK_P
           push GS_PAUSE
           pop  GameState    
        .endif
        ret
   .endif
KeyDownProc endp

;װ����Դ
LoadRes proc                             

    invoke GetDC,handle_Wnd                                 ;��һ���豸������(DC)����ȡһ�����
    mov handle_Dc , eax

    invoke CreateCompatibleDC,handle_Dc                     ;����һ����handle_Dc���ݵ��ڴ��豸�����Ļ�����DC��.
    mov handle_ImgDc,eax
    invoke LoadBitmap,hInstance ,BM_BMP                 ;����λͼ��Դ
    mov handle_ImgBmp,eax
    invoke SelectObject,handle_ImgDc,handle_ImgBmp      ;��һ������(handle_ImgBmp)ѡ��ָ�����豸������handle_ImgDc��
    
    invoke CreateCompatibleDC,handle_Dc
    mov handle_ImgwallDc,eax
    invoke LoadBitmap,hInstance ,BM_WALL
    mov handle_ImgwallBmp,eax
    invoke SelectObject,handle_ImgwallDc,handle_ImgwallBmp
    
    invoke CreateCompatibleDC,handle_Dc
    mov handle_BackDc,eax
    invoke CreateCompatibleBitmap,handle_Dc,dlgsize ,dlgsize
    mov handle_BackBmp,eax
    invoke SelectObject,handle_BackDc,eax

    ;00ffffffh�ǰ�ɫ
    invoke CreatePen,PS_SOLID,1,00804000h           ;�������ʣ�����ֵ�ǻ��ʵľ��
    mov handle_Pen ,eax
    invoke CreateSolidBrush,00ffffffh               ;����һ������ָ����ɫ��ˢ��,
    mov handle_Brush ,eax
    invoke SelectObject,handle_BackDc,handle_Pen            ;�����ʼ����뱳��
    invoke SelectObject,handle_BackDc,handle_Brush          ;��ˢ�Ӽ����뱳��
    invoke Rectangle,handle_BackDc,0,0,dlgsize,dlgsize          ;����һ�����ο򣬴�С��400x400;������Ϸ��ʼǰѡ��ҳ�����ɫ
    invoke RtlZeroMemory,addr Map_dup,mapsize2           ;��0�����һ���СΪmapsize2���ڴ�����Map_dup��
    
    push NULL
    pop  SnakeHead
    push NULL
    pop  SnakeTail
    push 0
    pop  NodeCount
    push GS_END
    pop  GameState
    invoke GetTickCount             ;����ʱ��
    mov RandomSeed,eax
    
    ret  
LoadRes endp

;WndProc�ĸ���������MSG�ṹ���ǰ�ĸ��ֶ�һһ��Ӧ,ÿ����һ����Ϣ���������һ�� WndProc ������
WndProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
    mov		eax,uMsg
    .if eax==WM_INITDIALOG
        push	hWin                    
        pop		handle_Wnd                          ;�洰�ھ��
        invoke SendDlgItemMessage,hWin,IDC_SBR1,SB_SETPARTS,sbParts,addr sbWidths
        invoke LoadRes       ;װ����Դ      
    .elseif eax==WM_PAINT   ;����ˢ��
        invoke DefWindowProc,hWin,uMsg,wParam,lParam
        invoke BitBlt,handle_Dc,0,0,dlgsize,dlgsize,handle_BackDc,0,0,SRCCOPY
        ret
    .elseif eax==WM_COMMAND ;���ڰ���
        mov		eax,wParam
        and		eax,0FFFFh
        .if eax==IDM_FILE_EXIT                  ;�˳�
            invoke SendMessage,hWin,WM_CLOSE,0,0
        .elseif eax==IDM_NEWGAME                ;��ʼ����Ϸ
            invoke NewGame
        .elseif eax==ID_GAMESPEED_FAST
            mov TIMER1_INTERVAL,50
            mov time_mul,20
        .elseif eax==ID_GAMESPEED_MIDDLE
            mov TIMER1_INTERVAL,100
            mov time_mul,10
        .elseif eax==ID_GAMESPEED_SLOW
            mov TIMER1_INTERVAL,200
            mov time_mul,5
        .elseif eax==ID_NUM1
            mov wall,5
        .elseif eax==ID_NUM2
            mov wall,10
        .elseif eax==ID_NUM3
            mov wall,20
        .elseif eax==ID_MAP_SMALL
            mov dlgsize,200
            mov mapsize,25
            mov mapsize2,625
        .elseif eax==ID_MAP_MIDDLE
            mov dlgsize,320
            mov mapsize,40
            mov mapsize2,1600
        .elseif eax==ID_MAP_BIG
            mov dlgsize,400
            mov mapsize,50
            mov mapsize2,2500
        .endif
    .elseif eax==WM_KEYDOWN ;���¼���
        invoke KeyDownProc,wParam
    .elseif eax==WM_CLOSE   ;�˳�
        invoke ClearGame    ;�ͷ�
        ;�رմ���ʱ�ͷž����Դ                                        
        invoke ReleaseDC,   handle_Wnd,handle_Dc
        invoke DeleteObject,handle_ImgBmp
        invoke DeleteObject,handle_BackBmp
        invoke DeleteObject,handle_Pen
        invoke DeleteObject,handle_Brush
        invoke DeleteDC,    handle_BackDc
        invoke DeleteObject,handle_ImgDc
        ;���ٴ���
        invoke DestroyWindow,hWin         
    .else
        invoke DefWindowProc,hWin,uMsg,wParam,lParam
        ret
    .endif
    xor    eax,eax
    ret

WndProc endp

WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD 
    LOCAL	wc:WNDCLASSEX       ;�ֲ�����wc��������
    LOCAL	msg:MSG             ;�ֲ�����msg,��Ϣ��

    mov		wc.cbSize,SIZEOF WNDCLASSEX         ;���ô������С
    mov		wc.style,CS_HREDRAW or CS_VREDRAW   ;
    mov		wc.lpfnWndProc,OFFSET WndProc       ;ָ��wndproc����
    mov		wc.cbClsExtra,NULL                  ;��ĸ����ڴ�Ϊ0
    mov		wc.cbWndExtra,DLGWINDOWEXTRA        ;���ڵĸ����ڴ�
    push	hInst                               
    pop		wc.hInstance                        ;����ǰʵ���ľ��hInst����
    mov		wc.hbrBackground,COLOR_BTNFACE+1    ;������ɫ
    mov		wc.lpszMenuName,OFFSET MenuName     ;ָ���˵���Դ����
    mov		wc.lpszClassName,OFFSET ClassName   ;ָ�����������Ա�ʶ���������
    invoke LoadIcon,NULL,IDI_APPLICATION
    mov		wc.hIcon,eax                        ;ͼ����,����ָ���������ͼ��
    mov		wc.hIconSm,eax                      ;
    invoke LoadCursor,NULL,IDC_ARROW
    mov	    wc.hCursor,eax                      ;������ָ��������״
    invoke RegisterClassEx,addr wc              ;ע�ᴰ��wc
    invoke CreateDialogParam,hInstance,addr DlgName,NULL,addr WndProc,NULL  ;���ݶԻ���ģ����Դ����һ����ģʽ�ĶԻ���
    invoke ShowWindow,handle_Wnd,SW_SHOWNORMAL      ;���ô��ڵ���ʾ״̬
    invoke UpdateWindow,handle_Wnd                  ;���´���(����Ϊ�����

    .while TRUE                                  
        invoke GetMessage,addr msg,NULL,0,0
        .BREAK .if !eax
        invoke TranslateMessage,addr msg
        invoke DispatchMessage,addr msg
    .endw
;-------------------------------------------
;�ڴ������ڡ���ʾ���ڡ����´��ں�������Ҫ��дһ����Ϣѭ�������ϵش���Ϣ������ȡ����Ϣ����������Ӧ��
    ;while(GetMessage(&msg,NULL,0,0))
    ;{
        ;TranslateMessage(&msg);
        ;DispatchMessage(&msg);
    ;}
;-------------------------------------
    mov		eax,msg.wParam
    ret

WinMain endp

main	proc
    invoke GetModuleHandle, NULL    ;��ȡӦ�ó�����������ֵĬ�ϱ�����eax��
    mov hInstance,eax               ;��eax�еľ������hInstance
    invoke GetCommandLine           ;������ǰ���̵��������ַ���,�޲���������ֵĬ�ϱ�����eax��
    mov CommandLine,eax 
    invoke InitCommonControls       ;��ʼ�����е�ͨ�ÿؼ�
    invoke WinMain, hInstance,NULL,CommandLine, SW_SHOWDEFAULT 
    invoke ExitProcess,eax          ;�˳�
main    endp
end		main

end start 
