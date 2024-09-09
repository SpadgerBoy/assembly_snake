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

;声明函数
ClearGame   proto
EndGame     proto
Random      proto Range:DWORD
TimeProc1   proto hWnd:HWND,uMsg:UINT,idEvent :UINT,dwTime:DWORD,wParam:WPARAM
TimeProc2   proto hWnd:HWND,uMsg:UINT,idEvent:UINT,dwTime:DWORD 
KeyDownProc proto dwKey :DWORD

.data
food               dd 20       ;糖豆数量
wall                dd 5        ;障碍物多少
dlgsize          dd 400      ;窗口大小 ，按最大初始化，
dlgsize_max     dd 400      ;窗口最大值
mapsize         dd 50       ;地图长
mapsize_max     dd 2500     ;地图长最大值
mapsize2        dd 50*50    ;地图大小


AppName			db '贪吃蛇',0
success         db '恭喜通过本关卡',0
Map_dup           db 50*50  dup(0)    ;游戏地图
g_sMsgGamePause db '游戏暂停',0
g_sMsgEndGame  db '游戏结束',0
FmtStrNodeCount db '当前得分： %d',0
ShowTimer       db '当前用时： %d.%d秒',0

ClassName		db 'DLGCLASS',0
MenuName		db 'MyMenu',0
DlgName			db 'MyDialog',0
sbParts         dd 3            ;底部分为三份
sbWidths        dd 0,200,405,0  ;底部三份的长度
TIMER1_INTERVAL dd 100          ;每100ms刷新一次页面
time_ms         dw 0
time_mul        db 10
time_s1         db 0
time_s2         db 0
flag            dd 0

.const 
;窗口的图标，ico
IDI_ICON			equ	201
IDM_FILE_EXIT		equ 10001   
IDM_NEWGAME			equ 10002   
IDC_SBR1			equ 1001    
BM_BMP				equ 1000    
BM_WALL             equ 1002   

;速度大小
ID_GAMESPEED_FAST   equ 333     
ID_GAMESPEED_MIDDLE equ 444     
ID_GAMESPEED_SLOW   equ 555     
;窗口大小
ID_MAP_SMALL        equ 70
ID_MAP_MIDDLE       equ 71
ID_MAP_BIG          equ 72
;障碍物多少
ID_NUM1 equ 11
ID_NUM2 equ 12
ID_NUM3 equ 13
;方向控制
DR_LEFT   equ  0        
DR_RIGHT  equ  1        
DR_UP     equ  2        
DR_DOWN   equ  3        
;游戏状态
GS_START   equ 1         ;游戏态为1
GS_PAUSE  equ 2         ;暂停态
GS_END    equ 3         ;终止态

TIMER1_ID equ 1000      ;定时器标号
TIMER2_ID equ 1001      
TIMER2_INTERVAL equ 1000    ;定时器触发间隔（毫秒）

MAP_NONE  equ 0
MAP_FOOD  equ 2
MAP_NODE  equ 3
MAP_WALL  equ 4

.data?
hInstance           HINSTANCE ?
CommandLine         LPSTR ?
handle_Wnd				dd ?        ;窗口句柄号
handle_Dc               dd ?        ;设备上下文环境的句柄
handle_ImgDc            dd ?        ;存储与handle_Dc兼容的内存设备上下文环境（DC）
handle_ImgBmp           dd ?        ;存储位图资源
handle_ImgwallDc        dd ?        ;
handle_ImgwallBmp       dd ?        ;
handle_BackDc           dd ?        ;
handle_BackBmp          dd ?        ;
handle_Pen              dd ?        ;画笔的句柄
handle_Brush            dd ?        ;刷子的句柄

SnakeHead    dd ?        ; 蛇头
SnakeTail    dd ?        ; 蛇尾
SnakeDirect  dd ?        ; Left Right up down
NodeCount    dd ?              ;记录得分

GameState         dd ?        
RandomSeed        dd ?

stringBuf          db 300 dup(?)  ; String Buffer
timeBuf         db 300 dup(?)   ;记录游戏用时

SNode struct
    pPrev   dd ?        ; Base
    x       dd ?        ; Base + 4  
    y       dd ?        ; Base + 8
    pNext   dd ?        ; Base + 12
SNode ends


.code 
start: 
 
 
;画地图的子程序
DrawMap proc                                 
    LOCAL x,y :DWORD                             ;注意地图的底，其实已经画好了
    LOCAL i,j :DWORD                             ;这个子程序就是在底上画上“豆子”和“蛇”
    LOCAL Pos :DWORD
    LOCAL pNode :DWORD

    invoke Rectangle,handle_BackDc,0,0,dlgsize ,dlgsize
  
    mov j, 0             ;j是行，先=0
    mov Pos, 0           ;相对的坐标
@@1:
    mov i, 0             ;i是列，=0
@@2:   
    mov ebx ,offset Map_dup 
    add ebx,Pos
    mov al,byte ptr [ebx]
    
    ;画面中每个点占8x8个像素点
    .if al == MAP_FOOD          ;画糖豆，MAP_FOOD
        mov eax, i
        shl eax,3               ;左移3位， i*8
        mov x , eax
        mov eax ,j
        shl eax ,3              ;左移3位， j*8
        mov y,eax
        invoke BitBlt,handle_BackDc,x,y,8,8,handle_ImgDc,8,0,SRCCOPY
        
    .elseif al==MAP_WALL        ;画墙
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
    cmp i,ecx           ;不足一列，继续循环
    jnz @@2             ;jump if not zero,结果不为0就跳转
    
    inc j               ;一列完，行加1
    cmp j,ecx            ;行没到终点，继续循环
    jnz @@1
      
    ;画蛇
    mov ebx , SnakeHead    ;蛇头                
@@3:
    cmp ebx , NULL
    jz  @@Break         ;ebx=0时，结束？？
    mov pNode ,ebx      ;保存蛇头的值  
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


;开始新游戏
NewGame proc 
    local pNode:dword ; the last node
    local x2:dword
    local y2:dword

    invoke ClearGame     ;新游戏开始前清空前面的游戏

    ; 初始时，蛇有5个节点
;***************************************************************
    ;头结点
    invoke LocalAlloc,LPTR,sizeof(SNode)  ;从局部堆中分配内存供程序使用，用来存放蛇头的位置
    .if eax == NULL 
        invoke MessageBox,handle_Wnd,addr AppName,addr AppName,MB_OK
    .endif
    mov SnakeHead , eax
    mov pNode ,eax
    mov ebx ,eax
    mov eax , NULL
    mov [ebx],eax   ; SnakeHead.pPrev = null，当前节点的前一个节点为空
    mov eax, 5
    mov [ebx+4],eax ; SnakeHead.x = 5
    mov eax,0
    mov [ebx+8],eax ; SnakeHead.y = 0     ;游戏开始时蛇头的位置（5，0）
    mov edi,OFFSET Map_dup
    add edi,5
    mov BYTE PTR[edi],MAP_NODE

    ;第2个节点
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

    ;第3个节点
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
    
    ;第4个节点
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
    
    ;第5个节点
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
    cmp al,  MAP_NONE           ;比较指令, MAP_NONE=0
    jne L4                      ;ZF=0时跳转到L4
    mov BYTE PTR[ebx],MAP_WALL  
    pop ecx
    loop L5
    
    invoke DrawMap                 ;画地图的子程序
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


;游戏结束
EndGame proc
    push GS_END
    pop  GameState
    invoke KillTimer,handle_Wnd,TIMER2_ID       ;关定时器2
    invoke KillTimer,handle_Wnd,TIMER1_ID       ;关定时器1
    invoke MessageBox,handle_Wnd,addr g_sMsgEndGame,addr AppName,MB_ICONINFORMATION    ;显示结束消息框
    ret
EndGame endp


;开始新游戏时清空之前的资源
ClearGame proc                                  
    LOCAL pNode :DWORD
    .if SnakeHead == NULL
        ret
    .endif

    ;清空游戏时间
    mov time_ms,0
    
    ;关闭计时器
    invoke KillTimer,handle_Wnd,TIMER1_ID          ;释放定时器1
    invoke KillTimer,handle_Wnd,TIMER2_ID          ;释放定时器2
     
    ;清空地图
    invoke RtlZeroMemory,addr Map_dup,mapsize2
    
    ;清空蛇
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


;生成随机数，用于更新障碍物和食物
Random proc Range:DWORD               
    mov eax, RandomSeed
    mov ecx, 23
    mul ecx
    add eax, 7
    and eax, 0FFFFFFFFh
    ror eax, 1              ;循环右移，减小二倍
    xor eax, RandomSeed
    mov RandomSeed, eax
    mov ecx, Range
    xor edx, edx            ;edx清零
    div ecx                 ;被除数在edx:eax中，商在eax中，余数在edx中；edx中已清零，故被除数就是eax中的数据
    mov eax, edx
    ret
Random endp


;更新地图页面，显示蛇的位置
TimeProc1 proc hWnd:HWND,uMsg:UINT,idEvent :UINT,dwTime:DWORD,wParam:WPARAM
    LOCAL pNode:DWORD                             ;功能是使蛇向前移动
    LOCAL Pos:DWORD
    LOCAL x1,y1:DWORD

    pushad                                       ;保存所有寄存器
    invoke KillTimer,handle_Wnd,TIMER1_ID            ;关定时器
    
    mov ebx , SnakeHead   
    mov eax,[ebx+4]
    mov x1,eax
    mov eax,[ebx+8]
    mov y1,eax
    mov eax, SnakeDirect
    mov ecx,mapsize
    .if eax == DR_LEFT                   ;方向是左,就把头的列-1
        dec x1
        cmp x1,0
        jge @@1
        invoke EndGame                  ;到地图边缘游戏结束
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
   .if(al==MAP_FOOD)                         ;吃到糖豆
        inc NodeCount                      ;记录得分，NodeCount++
        invoke wsprintf,addr stringBuf, addr FmtStrNodeCount,NodeCount ;输出为stringBuf，输入为FmtStrNodeCount,NodeCount 
        invoke SendDlgItemMessage,handle_Wnd,IDC_SBR1,SB_SETTEXT,2,addr stringBuf ;将消息输出到对话框
        mov esi,SnakeHead
        invoke LocalAlloc ,LPTR,sizeof(SNode)
        mov SnakeHead,eax
        mov edi,eax
        mov pNode,eax
        mov [esi],eax
        mov eax,esi
        mov [edi+12],eax                      ;后一个和前一个链接好
        mov eax,NULL
        mov [edi],eax 
        mov al,MAP_NODE                       
        mov eax,Pos
        mov BYTE PTR[eax],al 
        invoke SetTimer,handle_Wnd,TIMER2_ID,TIMER2_INTERVAL,addr TimeProc2         ;每1秒在地图上放一个豆
        jmp L
    .elseif(al==MAP_NONE)
        jmp L3
    .elseif(al==MAP_NODE)                  ;咬到自己时结束
        invoke EndGame
        popad
        ret
    .elseif(al==MAP_WALL)                   ;撞到障碍物时停止
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

    ;记录时间
    inc time_ms                      
    mov AX,time_ms
    mov BL,time_mul
    idiv BL
    mov time_s1,AL
    mov time_s2,AH
    invoke wsprintf,addr timeBuf, addr ShowTimer,time_s1,time_s2 
    invoke SendDlgItemMessage,handle_Wnd,IDC_SBR1,SB_SETTEXT,1,addr timeBuf ;将消息输出到对话框

     mov eax,GameState
    .if eax == GS_PAUSE
        mov eax,flag
        .if eax==0
            invoke MessageBox,handle_Wnd,addr g_sMsgGamePause,addr AppName,MB_ICONINFORMATION    ;显示暂停消息框
            mov flag,1
        .endif
    .endif
    mov eax,food
    .if(eax == NodeCount)
        push GS_END
        pop  GameState
        invoke KillTimer,handle_Wnd,TIMER2_ID       ;关定时器2
        invoke KillTimer,handle_Wnd,TIMER1_ID       ;关定时器1
        invoke MessageBox,handle_Wnd,addr success,addr AppName,MB_ICONINFORMATION
    .endif 
    mov eax,flag
    .if eax==0
        invoke SetTimer,handle_Wnd,TIMER1_ID,TIMER1_INTERVAL,addr TimeProc1    ;每xx秒刷新一次
    .endif

    popad                                                             ;恢复所有寄存器
    ret    
TimeProc1 endp

;随机更新食物
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
    mov ebx,offset Map_dup         ;如果不是0的话，就可以放豆
    add ebx,Pos                  ;下面的代码就是放豆
    mov al ,MAP_FOOD             
    mov byte ptr [ebx],al
    invoke KillTimer,handle_Wnd,TIMER2_ID  
    invoke DrawMap             
    invoke BitBlt,handle_Dc,0,0,dlgsize,dlgsize,handle_BackDc,0,0,SRCCOPY
    popad  
    ret
TimeProc2 endp

;键盘输入，运动控制
KeyDownProc proc dwKey :DWORD

    .if GameState == GS_END           ;GS_END=3,游戏结束，
        ret
    .elseif GameState == GS_PAUSE     ;GS_PAUSE =2,暂停态，点击S继续开始
        mov eax,dwKey
        .if eax == VK_S                 ;如果按S(START)，继续开始
            push GS_START
            pop  GameState
            mov flag,0
            invoke SetTimer,handle_Wnd,TIMER1_ID,TIMER1_INTERVAL,addr TimeProc1    ;每xx秒刷新一次
        .endif
        ret
    .elseif GameState == GS_START     ;GS_START=1，游戏态，允许输入上、下、左、右、暂停
        mov eax,dwKey
        .if eax == VK_UP                 ;如果向上
            .if SnakeDirect != DR_DOWN      ;蛇头不能是向下的，
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

;装载资源
LoadRes proc                             

    invoke GetDC,handle_Wnd                                 ;从一个设备上下文(DC)中提取一个句柄
    mov handle_Dc , eax

    invoke CreateCompatibleDC,handle_Dc                     ;创建一个与handle_Dc兼容的内存设备上下文环境（DC）.
    mov handle_ImgDc,eax
    invoke LoadBitmap,hInstance ,BM_BMP                 ;加载位图资源
    mov handle_ImgBmp,eax
    invoke SelectObject,handle_ImgDc,handle_ImgBmp      ;把一个对象(handle_ImgBmp)选入指定的设备描述表（handle_ImgDc）
    
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

    ;00ffffffh是白色
    invoke CreatePen,PS_SOLID,1,00804000h           ;创建画笔，返回值是画笔的句柄
    mov handle_Pen ,eax
    invoke CreateSolidBrush,00ffffffh               ;创建一个具有指定颜色的刷子,
    mov handle_Brush ,eax
    invoke SelectObject,handle_BackDc,handle_Pen            ;将画笔加载入背景
    invoke SelectObject,handle_BackDc,handle_Brush          ;将刷子加载入背景
    invoke Rectangle,handle_BackDc,0,0,dlgsize,dlgsize          ;绘制一个矩形框，大小是400x400;这是游戏开始前选择页面的颜色
    invoke RtlZeroMemory,addr Map_dup,mapsize2           ;用0来填充一块大小为mapsize2的内存区域（Map_dup）
    
    push NULL
    pop  SnakeHead
    push NULL
    pop  SnakeTail
    push 0
    pop  NodeCount
    push GS_END
    pop  GameState
    invoke GetTickCount             ;返回时间
    mov RandomSeed,eax
    
    ret  
LoadRes endp

;WndProc的各个参数和MSG结构体的前四个字段一一对应,每产生一条消息，都会调用一次 WndProc 函数。
WndProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
    mov		eax,uMsg
    .if eax==WM_INITDIALOG
        push	hWin                    
        pop		handle_Wnd                          ;存窗口句柄
        invoke SendDlgItemMessage,hWin,IDC_SBR1,SB_SETPARTS,sbParts,addr sbWidths
        invoke LoadRes       ;装载资源      
    .elseif eax==WM_PAINT   ;窗口刷新
        invoke DefWindowProc,hWin,uMsg,wParam,lParam
        invoke BitBlt,handle_Dc,0,0,dlgsize,dlgsize,handle_BackDc,0,0,SRCCOPY
        ret
    .elseif eax==WM_COMMAND ;窗口按键
        mov		eax,wParam
        and		eax,0FFFFh
        .if eax==IDM_FILE_EXIT                  ;退出
            invoke SendMessage,hWin,WM_CLOSE,0,0
        .elseif eax==IDM_NEWGAME                ;开始新游戏
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
    .elseif eax==WM_KEYDOWN ;按下键盘
        invoke KeyDownProc,wParam
    .elseif eax==WM_CLOSE   ;退出
        invoke ClearGame    ;释放
        ;关闭窗口时释放句柄资源                                        
        invoke ReleaseDC,   handle_Wnd,handle_Dc
        invoke DeleteObject,handle_ImgBmp
        invoke DeleteObject,handle_BackBmp
        invoke DeleteObject,handle_Pen
        invoke DeleteObject,handle_Brush
        invoke DeleteDC,    handle_BackDc
        invoke DeleteObject,handle_ImgDc
        ;销毁窗口
        invoke DestroyWindow,hWin         
    .else
        invoke DefWindowProc,hWin,uMsg,wParam,lParam
        ret
    .endif
    xor    eax,eax
    ret

WndProc endp

WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD 
    LOCAL	wc:WNDCLASSEX       ;局部变量wc，窗体类
    LOCAL	msg:MSG             ;局部变量msg,消息类

    mov		wc.cbSize,SIZEOF WNDCLASSEX         ;设置窗口类大小
    mov		wc.style,CS_HREDRAW or CS_VREDRAW   ;
    mov		wc.lpfnWndProc,OFFSET WndProc       ;指向wndproc函数
    mov		wc.cbClsExtra,NULL                  ;类的附加内存为0
    mov		wc.cbWndExtra,DLGWINDOWEXTRA        ;窗口的附加内存
    push	hInst                               
    pop		wc.hInstance                        ;将当前实例的句柄hInst传入
    mov		wc.hbrBackground,COLOR_BTNFACE+1    ;背景颜色
    mov		wc.lpszMenuName,OFFSET MenuName     ;指定菜单资源名字
    mov		wc.lpszClassName,OFFSET ClassName   ;指定类名，用以标识这个窗口类
    invoke LoadIcon,NULL,IDI_APPLICATION
    mov		wc.hIcon,eax                        ;图标句柄,用来指定窗口类的图标
    mov		wc.hIconSm,eax                      ;
    invoke LoadCursor,NULL,IDC_ARROW
    mov	    wc.hCursor,eax                      ;标句柄，指定光标的形状
    invoke RegisterClassEx,addr wc              ;注册窗口wc
    invoke CreateDialogParam,hInstance,addr DlgName,NULL,addr WndProc,NULL  ;根据对话框模板资源创建一个无模式的对话框
    invoke ShowWindow,handle_Wnd,SW_SHOWNORMAL      ;设置窗口的显示状态
    invoke UpdateWindow,handle_Wnd                  ;更新窗口(参数为句柄）

    .while TRUE                                  
        invoke GetMessage,addr msg,NULL,0,0
        .BREAK .if !eax
        invoke TranslateMessage,addr msg
        invoke DispatchMessage,addr msg
    .endw
;-------------------------------------------
;在创建窗口、显示窗口、更新窗口后，我们需要编写一个消息循环，不断地从消息队列中取出消息，并进行响应。
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
    invoke GetModuleHandle, NULL    ;获取应用程序句柄，返回值默认保存在eax中
    mov hInstance,eax               ;将eax中的句柄传入hInstance
    invoke GetCommandLine           ;检索当前进程的命令行字符串,无参数，返回值默认保存在eax中
    mov CommandLine,eax 
    invoke InitCommonControls       ;初始化所有的通用控件
    invoke WinMain, hInstance,NULL,CommandLine, SW_SHOWDEFAULT 
    invoke ExitProcess,eax          ;退出
main    endp
end		main

end start 
