10 clr
15 x=0:y=0:z=0:rd=0:e=0:m=0:ea=0:j=0:d=0:c=0:w=0:t=0:l=0:q=0:p1=0:sg=0:it=0:dt=0:ni=0
16 xv=0:yv=0:n=0:i=0:ce=0:se=0:k=0:xe=0:ye=0:ze=0:a=0:v=0
20 p=8195:p1=3.14159265:rd=p1/180:kv=0
25 pokep+56,1:sys8192:pokep+56,0
30 da=24:mo=11:yr=2026:hh=22:mi=0:tz=1:la=50.08:lo=14.42
40 gosub3000
50 t0=ti
52 ifti-t0<180then52
55 print"{down}stiskni klavesu...";:poke198,0:wait198,1:poke198,0
57 print"{clr}{down}{yel}pocitam polohy teles......{wht}":gosub1010:gosub4600:gosub4500
60 pokep+9,kv:sys8192:kv=1
70 ex=peek(p+8):poke53280,0:poke53281,0:print"{clr}{wht}";
80 ifex=1thenprint"skymap64 v1.1 - nashledanou!":end
90 v=peek(p+6)+256*peek(p+7):ifv>32767thenv=v-65536
100 t=hh*60+mi+v
110 ift<0thent=t+1440:gosub500:goto110
120 ift>=1440thent=t-1440:gosub400:goto120
130 hh=int(t/60):mi=t-60*hh
140 ifex=2then40
145 ifex=4andv=0andtcthengosub4500:goto60
150 print"{down}{yel}prepocitavam...{wht}":gosub1010:tc=0:ifex=4thengosub4600:gosub4500
160 goto60
400 da=da+1:gosub450:ifda<=dmthenreturn
410 da=1:mo=mo+1:ifmo>12thenmo=1:yr=yr+1
420 return
450 dm=31:ifmo=4ormo=6ormo=9ormo=11thendm=30
460 ifmo=2thendm=28:ifyr/4=int(yr/4)thendm=29
470 return
500 da=da-1:ifda>0thenreturn
510 mo=mo-1:ifmo<1thenmo=12:yr=yr-1
520 gosub450:da=dm:return
800 ifx=0thenan=sgn(y)*p1/2:return
810 an=atn(y/x):ifx<0thenan=an+p1
820 return
900 v=int(c*16384+.5):ifv<0thenv=v+65536
905 hb=int(v/256):pokea,v-hb*256:pokea+1,hb:return
1010 ut=hh+mi/60-tz
1020 d=367*yr-int(7*(yr+int((mo+9)/12))/4)+int(275*mo/9)+da-730530+ut/24
1030 d2=d-1.5:g=280.46061837+.98564736629*d2+360*(d2-int(d2))+lo
1040 g=g-360*int(g/360):lt=g*rd:v=int(g/360*65536):ifv>65535thenv=0
1050 a=p:gosub905
1060 v=int(la/360*65536+.5):ifv<0thenv=v+65536
1070 a=p+2:gosub905:v=hh*60+mi:a=p+4:gosub905:v=0:a=p+6:gosub905
1075 pokep+52,da:pokep+53,mo:v=yr:a=p+54:gosub905
1080 ec=(23.4393-3.563e-7*d)*rd:ce=cos(ec):se=sin(ec)
1090 gosub1110:gosub1210:goto1310
1110 w=(282.9404+4.70935e-5*d)*rd:e=.016709-1.151e-9*d:m=(356.047+.9856002585*d)*rd
1120 ms=m:ws=w:gosub1500
1130 xv=cos(ea)-e:yv=sqr(1-e*e)*sin(ea)
1140 xs=xv*cos(w)-yv*sin(w):ys=xv*sin(w)+yv*cos(w)
1150 x=xs:y=ys:z=0:k=0:gosub1600:return
1210 n=(125.1228-.0529538083*d)*rd:i=5.1454*rd:w=(318.0634+.1643573223*d)*rd
1220 a1=60.2666:e=.0549:m=(115.3654+13.0649929509*d)*rd:mm=m
1230 gosub1500:xv=a1*(cos(ea)-e):yv=a1*sqr(1-e*e)*sin(ea):gosub1700
1240 x=xh:y=yh:gosub800:ql=an:qb=atn(zh/sqr(xh*xh+yh*yh)):qr=sqr(xh*xh+yh*yh+zh*zh)
1250 ml=mm+w+n:dd=ml-ms-ws:ff=ml-n
1260 q1=-1.274*sin(mm-2*dd)+.658*sin(2*dd)-.186*sin(ms)-.059*sin(2*mm-2*dd)
1265 q1=q1-.057*sin(mm-2*dd+ms)+.053*sin(mm+2*dd)+.046*sin(2*dd-ms)
1270 q1=q1+.041*sin(mm-ms)-.035*sin(dd)-.031*sin(mm+ms):ql=ql+q1*rd
1275 q2=-.173*sin(ff-2*dd)-.055*sin(mm-ff-2*dd)-.046*sin(mm+ff-2*dd)
1280 q2=q2+.033*sin(ff+2*dd)+.017*sin(2*mm+ff):qb=qb+q2*rd
1285 qr=qr-.58*cos(mm-2*dd)-.46*cos(2*dd)
1290 x=qr*cos(qb)*cos(ql):y=qr*cos(qb)*sin(ql):z=qr*sin(qb):k=1:gosub1600:return
1310 restore:fork=2to6:readn0,n1,i0,i1,w0,w1,a1,e0,e1,m0,m1
1320 n=(n0+n1*d)*rd:i=(i0+i1*d)*rd:w=(w0+w1*d)*rd:e=e0+e1*d:m=(m0+m1*d)*rd
1330 gosub1500:xv=a1*(cos(ea)-e):yv=a1*sqr(1-e*e)*sin(ea):gosub1700
1340 x=xh+xs:y=yh+ys:z=zh:gosub1600:next:return
1500 ea=m+e*sin(m)*(1+e*cos(m))
1510 forj=1to2:ea=ea-(ea-e*sin(ea)-m)/(1-e*cos(ea)):next:return
1600 xe=x:ye=y*ce-z*se:ze=y*se+z*ce
1610 ifk=1thenc=cos(la*rd):xe=xe-c*cos(lt):ye=ye-c*sin(lt):ze=ze-sin(la*rd)
1625 r=sqr(xe*xe+ye*ye+ze*ze):a=p+10+k*6
1630 c=xe/r:gosub900:c=ye/r:a=a+2:gosub900:c=ze/r:a=a+2:goto900
1700 u1=xv*cos(w)-yv*sin(w):u2=xv*sin(w)+yv*cos(w)
1710 xh=cos(n)*u1-sin(n)*u2*cos(i):yh=sin(n)*u1+cos(n)*u2*cos(i):zh=u2*sin(i):return
2000 data48.3313,3.24587e-5,7.0047,5e-8,29.1241,1.01444e-5,.387098
2001 data.205635,5.59e-10,168.6562,4.0923344368
2010 data76.6799,2.4659e-5,3.3946,2.75e-8,54.891,1.38374e-5,.72333
2011 data.006773,-1.302e-9,48.0052,1.6021302244
2020 data49.5574,2.11081e-5,1.8497,-1.78e-8,286.5016,2.92961e-5,1.523688
2021 data.093405,2.516e-9,18.6021,.5240207766
2030 data100.4542,2.76854e-5,1.303,-1.557e-7,273.8777,1.64505e-5,5.20256
2031 data.048498,4.469e-9,19.895,.0830853001
2040 data113.6634,2.3898e-5,2.4886,-1.081e-7,339.3939,2.97661e-5,9.55475
2041 data.055546,-9.499e-9,316.967,.0334442282
3000 print"{clr}{wht}";:poke53280,0:poke53281,0
3010 print"{cyn}         *** skymap64 v1.1 ***{wht}"
3020 print"{down}datum, cas a misto pozorovani"
3030 print"(return = ponechat puvodni hodnotu)"
3040 print"den           "da;:inputda
3050 print"mesic         "mo;:inputmo
3060 print"rok           "yr;:inputyr
3070 print"hodina        "hh;:inputhh
3080 print"minuta        "mi;:inputmi
3090 print"pasmo (utc+)  "tz;:inputtz
3100 print"zem. sirka    "la;:inputla
3110 print"zem. delka    "lo;:inputlo
3120 print"{cyn}ovladani:{wht}"
3130 print"kurzor/joy  {yel}otaceni pohledu{wht}"
3137 print"+ -         {yel}priblizit / oddalit{wht}"
3144 print"s v j z     {yel}sever/vychod/jih/zapad{wht}"
3151 print", .         {yel}cas -/+ 10 minut{wht}"
3158 print": ;         {yel}cas -/+ 1 hodina{wht}"
3165 print"return      {yel}prepocitat planety (*){wht}"
3172 print"c n m       {yel}cary/nazvy/messier{wht}"
3179 print"h i         {yel}hledat / casy zapadu{wht}"
3186 print"d q         {yel}nove datum / konec{wht}"
3200 return
4000 dt=0:rr=1:ifb=1thenrr=1.0351
4010 forit=1toni:d=d0+dt:gosub4100
4020 c=(sin(h0*rd)-sp*sin(de))/(cp*cos(de)):ifabs(c)>1thenev=-1:return
4030 hx=p1/2:ifc<>0thenhx=atn(sqr(1-c*c)/c):ifc<0thenhx=hx+p1
4040 df=sg*hx-sl+ra:df=df-2*p1*int(df/(2*p1)):ifit>1anddf>p1thendf=df-2*p1
4050 dt=dt+df/(2*p1)*rr:next:ev=d0+dt:return
4100 x=d-1.5:sl=(280.46061837+.98564736629*x+360*(x-int(x))+lo)*rd:t=x/36525
4110 ifb=1then4140
4120 l=280.46+.9856474*x:g=(357.528+.9856003*x)*rd:l=(l+1.915*sin(g)+.02*sin(2*g))*rd:q=0:goto4170
4140 l=218.32+481267.881*t+6.29*sin((134.9+477198.85*t)*rd)-1.27*sin((259.2-413335.38*t)*rd)
4150 l=l+.66*sin((235.7+890534.23*t)*rd)+.21*sin((269.9+954397.7*t)*rd)
4155 l=l-.19*sin((357.5+35999.05*t)*rd)-.11*sin((186.6+966404.05*t)*rd)
4160 q=5.13*sin((93.3+483202.03*t)*rd)+.28*sin((228.2+960400.87*t)*rd)
4165 q=(q-.28*sin((318.3+6003.18*t)*rd)-.17*sin((217.6-407332.2*t)*rd))*rd:l=l*rd
4170 x=cos(q)*cos(l):y=cos(q)*sin(l)*ce-sin(q)*se:z=cos(q)*sin(l)*se+sin(q)*ce
4180 gosub800:ra=an:de=atn(z/sqr(x*x+y*y)):return
4300 ifev<0thenprinttx$;:return
4310 x=ev+tz/24:dy=int(x)-dg:x=(x-int(x))*24+1/120:h=int(x):m=int((x-h)*60)
4320 printright$(str$(100+h),2)":"right$(str$(100+m),2);:ifdy=1thenprint" (zitra)";
4330 return
4500 print"{clr}{cyn}         *** skymap64 v1.1 ***{wht}"
4510 print"{down}datum: "mid$(str$(da),2)"."mid$(str$(mo),2)"."mid$(str$(yr),2)
4520 print"{down}{yel}slunce zapada:{wht}      ";:ev=e1:tx$="nezapada":gosub4300:print
4530 print"{down}{yel}astronomicka noc:{wht}   ";:ev=e2:tx$="nenastava":ife2>=0thenprint"od ";
4535 gosub4300
4540 ife2>=0thenprint:print"                    do ";:ev=e3:gosub4300
4545 print
4550 print"{down}{yel}mesic zapada:{wht}       ";:ev=e4:tx$="nezapada":gosub4300:print
4560 print"{down}{down}stiskni klavesu...";:poke198,0:wait198,1:poke198,0:return
4600 dg=367*yr-int(7*(yr+int((mo+9)/12))/4)+int(275*mo/9)+da-730530:ds=d:sp=sin(la*rd):cp=cos(la*rd)
4610 d0=dg+(12-tz)/24:b=0:h0=-.833:sg=1:ni=2:gosub4000:e1=ev
4620 h0=-18:ife1>=0thend0=e1:ni=1
4625 gosub4000:e2=ev:e3=-1:ife2>=0thend0=e2:sg=-1:ni=2:gosub4000:e3=ev
4630 d0=ds:b=1:h0=.125:sg=1:ni=3:gosub4000:e4=ev
4640 d=ds:tc=1:return
