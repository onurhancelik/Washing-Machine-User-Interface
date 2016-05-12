ORG 0000H
	SJMP MAIN
	
ORG 0003H ;On_Off / Start_Pause - INTERRUPT-0
	LJMP ON_START ;yapilan interrupt'in on/off veya start/pause butonundan gelmesine göre ilgili islemler yapiliyor
ORG 000BH
	ACALL TIMER_INT ;Timer-0'da interrupt meydana gelince ilgili islemlerin oldugu yere gidilir
	RETI
	
ORG 0013H
	LJMP SELECT_MOD ;Mod butonlarina basildiginda interrupt-1 etkin hale gelir ve islemlerin oldugu yere gidilir

ORG 001BH
	LJMP YAZDIR ;Timer-1 interrupt'i, 7-Segment'ler icin gösterge zaman araligini belirler
	
ORG 0030H
	MAIN:
	S1    EQU P1.0 ;Port-1'in ilk 4 ucu 4-Digit-7-Segment-Display'e baglidir ve hangi digit'in etkin oldugunu belirler
	S2    EQU P1.1
	S3    EQU P1.2
	S4    EQU P1.3
	PORT EQU P0 ; 7-Segment'in göstergelerine baglanan porttur
	MOV DPTR,#num ;7-Segment gösterimi için bellekte yer alan hexadecimal olarak bulunan sayilarin bellek adresi DPTR register'1na atilir
	W_LED EQU P2.2 ;Wash-Rinse-Spin Led'leri Port-2'nin ilgili uclarina baglidirlar
	R_LED EQU P2.1
	S_LED EQU P2.0
	Motor0 EQU P2.6 ;Devrede kullandigimiz DC Motor'un girislerini ayarladik
	Motor1 EQU P2.7
	Buzzer EQU P3.7 ;Devrede kullandigimiz ses kaynagi olan Buzzer'in girisi
	CLR Buzzer ;Buzzer'i temizledik
	SETB IT0 ;Interrupt 0 ve 1'in düsen kenarli olmasi ayarlandi
	SETB IT1
	MOV IE,#10000001B ;EX0 interrupt'i etkin hale getirildi On/Off butonu icin
	MOV TMOD,#00100001B ;Timer 0 ve 1'in modlari ayarlandi
	SJMP $
	
TIMER_INT: ;Timer-0'da kesme meydana gelince ilgili islemler yapilir
	CLR TF0  ;Timer Flag'leri temizlenir
	CLR TR0
	
	DJNZ R0,_50K ;Eger 1sn. olmadiysa _50K label'ina dallanilir
	SJMP AYARLA ;Eger 1sn. olduysa 7-Segment gösterimini saglayan register'larin degisimi icin dallanma olur
	CONT2:
	DJNZ R2,NEXT ;Rinse Led'i için gereken zamanin gelip gelmedigi kontrol edilir
	CPL W_LED ;Eger Rinse zamani geldiyse ilgili wash led'i kapatilip, rinse led'i yakilir
	CPL R_LED
	SJMP CONT
	NEXT:
	DJNZ R3,CONT ;Spin Led'i için gereken zamanin gelip gelmedigi kontrol edilir
	CPL R_LED ;Eger Spin zamani geldiyse ilgili rinse led'i kapatilip, rinse led'i yakilir
	CPL S_LED
	CONT:
		DJNZ R1,ONE_SEC ;Toplam sürenin dolup dolmadigi kontrol edilir, dolmadiysa yeniden 1sn. için ayarlanmalar yapilir
		CPL S_LED ;Makina süresi dolduysa Spin Led'i kapatilir
		CLR TR1 ;Timer-1 ekran kapatilir
		SETB EX1 ;Interrupt-1 - Mod Butonlari tekrar aktif hale getirilir
		CPL Motor1 ;Motor'u durdurduk
		ACALL Buzz ;Yikama bittiginde ses ötmesi icin Buzzer'i ayarladik "Buzz" alt programinda
		ACALL Default_Ata ;Makina calisir halde, tekrardan default degerlerin atandigi alt-program cagrildi
		SETB TR1;Timer-1 ekran acilir
		SJMP N_SEC
	ONE_SEC:
	MOV R0,#20 ; 1sn için tekrar R0 register'ina ilgili deger atanir
	_50K:
	MOV TH0,#3CH
	MOV TL0,#0B0H
	SETB TR0
	N_SEC:
	RET
	
AYARLA: DEC R4 ;7-segment'teki son rakam azaltilir
		CJNE R4,#0FFH,CONT2 ;eger son rakam eksi olmadiysa devam edilir
		MOV R4,#9 ;son rakam eksi olduysa 9'a tamamlanir
		DEC R5 ;2. rakam azaltilir
		CJNE R5,#0FFH,CONT2 ;2. rakam eksi olmadiysa devam edilir
		MOV R5,#5 ;2. rakam eksi olduysa 5'e tamamlan1r
		DEC R6 ;3. rakam azaltilir
		SJMP CONT2	

YAZDIR: ;Timer-1 için kesme meydana gelince 7-segment'te degerlerin gösterilmesi saglanir
	CLR S1 ;ilgili digit aktif hale getirtilir
	MOV A,R4 ;ilgili digite gönderilecek rakam Accumulator'e gönderilir
	ACALL send_num ;Rakamin 7-segment için gereken hexadecimal sayisini elde etmek için gereken yere dallanilir
	SETB S1 ;tekrar ilgili digit in-aktif hale getirilir
	
	CLR S2
	MOV A,R5
	ACALL send_num
	SETB S2
	
	CLR S3
	MOV A,R6
	ACALL send_num
	SETB S3
	
	CLR S4
	MOV A,#0
	ACALL send_num
	SETB S4
	RETI
	
ON_START: ;Interrupt-0'a sebep olan butonun ne olduguna karar verilir ve o islemi gerceklestirecek alt programlar cagilir
	MOV C,P2.3 ;P2.3 pini On/Off butonuna baglidir
	JNC Call_On ;Eger On/Off butonuna basildiysa Call_On'a dallanilir
	SJMP Call_SP ;Aksi halde Call_SP'ye dallanilir
	
	Call_On:
		SETB RS1 ;On_Off tusuna basildiginin izini tutmak icin register bank degistirilip ilgili register degeri ayarlanir
		MOV R1,#1
		CLR RS1 ;default register bank tekrar secilir
		ACALL ON_OFF ;On_Off'a dair islemler icin alt-program cagrilir
		SJMP End_OS ;Cikisa gidilir
	Call_SP:
		SETB RS1 ;Eger Start/Pause butonuna basildiysa makinanin acik olup olmadigi icin register bank degistirilip ilgili register kontrol edilir
		CJNE R1,#1,End_OS1 ;Eger makina acik degilse -OFF konumundaysa- ilgili yere dallanilir
		ACALL S_P ;Start/Pause islemleri icin ilgili alt-program cagrilir
		SJMP End_OS ;Cikisa gidilir
	End_OS1:
		CLR RS1 ;default register bank
	End_OS:
		RETI
		
ON_OFF: ;On/Off butonu icin
	SETB RS1 ;farkli bir register bank secilerek ilgili register kontrol edilir
	CJNE R0,#0,OFF ;Eger R0 register'i 0 degilse o zaman OFF konumuna gecilecektir
	INC R0 ;ON konumuna gecilecek. ON konumuna gecildigine dair bilgi birakilir ilgili register'a
	CLR RS1 ;default register bank
	MOV IE,#10001111B ;EX0 interrupt'ina ek olarak EX1,ET0,ET1 interrupt'lari da etkin hale getirildi
	ACALL Default_Ata ;ilgili atamalar icin alt program cagrildi
	SETB TR1 ;Ekranda anlik süre gösterimi icin timer-1 calistirildi
	SJMP END_ON ;cikisa gidilir
	OFF:
	DEC R0 ;R0 register'i OFF'a gecildigine dair bilgi icin azaltilir
	MOV R1,#0 ;OFF konumuna gectigimizi Start/Pause butonunun bilmesi icin ilgili register ayarlandi
	CLR RS1 ;OFF durumuna gecilince makinanin tüm islevleri etkisiz hale getirilir
	CLR TR0 ;Timer'lar durdurulur
	CLR TR1
	SETB W_LED ;Led'ler söner
	SETB R_LED
	SETB S_LED
	SETB Motor1 ;Motor durdurulur
	MOV IE,#10000001B ;EX1,ET0,ET1 timer'lari etkisiz hale getirilir
	END_ON:
	RET
	
Default_Ata: ;Default olarak makina daily Mod'dadir. 
	MOV R1,#60 ;60 sn. sürmektedir, gösterge ve timer'lar için gereken register atamalari yapilir
	MOV R2,#35
	MOV R3,#50
	MOV R4,#0
	MOV R5,#0
	MOV R6,#1
	MOV R7,#0 ;PreWash'a basilmadigi belirtilir
	MOV R0,#20 ;Süre hesaplamasinda 1 saniyeyi olusturmak icin kullanilan register
	MOV TH0,#3CH ;Timer-0 - 16bit'lik - 50000microsn. 
	MOV TL0,#0B0H
	MOV TH1,#-10 ;Timer-1 - Yükleme degerleri
	MOV TL1,#-10
	MOV B,#0
	RET	
	
SELECT_MOD:
	MOV C,P1.7 ;Mod seçimi - Daily,Wool,Cotton veya PreWash'a göre dallanma olur.
	JNC DAILY
	MOV C,P1.6
	JNC WOOL
	MOV C,P1.5
	JNC COTTON
	MOV C,P1.4
	JNC PWASH
	
	DAILY: ;Daily Mod'u 60 sn. sürmektedir, gösterge ve timer'lar için gereken register atamalari yapilir
	MOV R1,#60
	MOV R2,#35
	MOV R3,#50
	
	MOV R4,#0
	MOV R5,#0
	MOV R6,#1
	MOV R7,#0 ;PreWash'a basilmadigi belirtilir
	SJMP END_MOD ;Select_Mod'dan cikilir
	WOOL: ;Wool mod'u 90 sn. sürmektedir, gösterge ve timer'lar için gereken register atamalari yapilir
	MOV R1,#90
	MOV R2,#55
	MOV R3,#75
	
	MOV R4,#0
	MOV R5,#3
	MOV R6,#1
	MOV R7,#0 ;PreWash'a basilmadigi belirtilir
	SJMP END_MOD ;Select_Mod'dan cikilir
	COTTON: ;Cotton mod'u 120 sn. sürmektedir, gösterge ve timer'lar için gereken register atamalari yapilir
	MOV R1,#120
	MOV R2,#75
	MOV R3,#100
	
	MOV R4,#0
	MOV R5,#0
	MOV R6,#2
	MOV R7,#0 ;PreWash'a basilmadigi belirtilir
	SJMP END_MOD ;Select_Mod'dan cikilir
	PWASH: ;PreWash seçili mod'a 15sn. ekler, gösterge ve timer'lar için gereken register atamalari yapilir
	CJNE R7,#0,END_MOD ;Sadece 1 kere PreWash'a basilabilinir her ana mod seçimi sonrasi
	MOV A,R1
	ADD A,#15
	MOV R1,A
	MOV A,R2
	ADD A,#15
	MOV R2,A
	MOV A,R3
	ADD A,#15
	MOV R3,A
	
	MOV A,R4
	ADD A,#5
	MOV R4,A
	
	MOV A,R5
	ADD A,#1
	MOV R5,A
	INC R7	;PreWash'a basildigini belirtiriz R7 register'ini artirarak
	END_MOD:
	RETI
	
S_P: ;Yapilan istegin hangisi oldugunu bulmada "B Register"ini kullandik
	MOV A,B ;B Register'ini Accu'ye atarak sartli dallanmalari kullanmayi sagladik
	JZ Call_Start ;Eger 0 ise ilk defa calistiriliyordur
	CJNE A,#1,Call_Unpause ;Eger B register'i 0 degil ve de 1'den farkliysa Unpause olmustur
	SJMP Call_Pause ;Eger 1 ise Pause olmustur
	Call_Start:
		INC A ;Start'a basildigini ilerde anlamak icin artirdik B register'ini (accu yardimiyla)
		MOV B,A 
		LJMP START ;START'a atladik ilgili ilkleme ve özelliklerin ayari icin
	Call_Pause:
		INC A ;Pause'a basildigini ilerde anlamak icin artirdik B register'ini
		MOV B,A
		LJMP PAUSE ;PAUSE'a atladik ilgili islemler icin
	Call_Unpause:
		MOV B,#1 ;B Register'ina 1 atadik Unpause durumunda oldugunu anlamak icin
		LJMP UNPAUSE ;UNPAUSE'a atladik
	Out_SP:
	RET

START:
	CPL W_LED ;WASH LED'ini yanar makina baslatilinca
	SETB TR0 ;Timer-0 baslatilir, genel sure isletilir
	CLR EX1 ;Interrupt-1 yani MOD Butonlari etkisiz hale getirilir makinanin calistigi süre boyunca
	CPL Motor1 ;Motorun dönmesini baslattik(saat yönünde) START butonuna basilmasi ile
	LJMP Out_SP
	
PAUSE:
	CLR TR0 ;Makinanin calisma süresini belirleyen Timer-0'i durdurduk
	CPL Motor1 ;Motor'u durdurduk 
	LJMP Out_SP ;Programin akisini ilgili yere gönderdik

UNPAUSE:
	SETB TR0 ;Makinanin calisma süresini belirleyen Timer-0'i tekrar baslattik
	CPL Motor1 ;Motor'u calistirdik
	LJMP Out_SP ;Program akisini ilgili yere gönderdik

Buzz:
	SETB Buzzer ;Sesi actik
	MOV R0,#0FFH ;belirli süre zaman verdik sesin duyulmasi için
	dongu:MOV R1,#0FFH
	DJNZ R1,$
	DJNZ R0,dongu
	CLR Buzzer ;Sesi kapattik
	RET ;alt programdan cikilir
	
send_num:
    MOVC A,@A+DPTR ;ilgili rakamin 7-segment için gereken deger DPTR register'i ile alinir
    MOV PORT,A ;Port'a yollanir
    CLR A ;Acu temizlenir
	ACALL delay ;Ve bir zaman gecikmesi verilir 7-segment'te ilgili degerin görünmesi için
    RET
	
delay: setb rs1 ;farkli bir register bank kullanimi için RS1 biti set edilir
   	   mov r5,#0FFh       
loop2: djnz r5,loop2
	   clr rs1 ;rs1 biti temizlenir
       ret

        ORG 200H
num:    DB 7EH,30H,6DH,79H,33H,5BH,5FH,70H,7FH,7BH ;7-segment için gereken hexadecimal sayilar
	END