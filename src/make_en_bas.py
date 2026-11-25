#!/usr/bin/env python3
"""Create the English BASIC front-end (planet_en.bas) from the Czech one."""
import os
D = os.path.dirname(os.path.abspath(__file__))
b = open(os.path.join(D, 'planet.bas')).read()
T = [
 ('30 da=24:mo=11:yr=2026:hh=22:mi=0:tz=1:la=50.08:lo=14.42', '30 da=24:mo=11:yr=2026:hh=22:mi=0:tz=0:la=51.48:lo=0'),
 ('stiskni klavesu...', 'press any key...'),
 ('pocitam polohy teles......', 'computing positions......'),
 ('skymap64 v1.1 - nashledanou!', 'skymap64 v1.1 - goodbye!'),
 ('prepocitavam...', 'computing...'),
 (' (zitra)', ' (+1 day)'),
 ('datum: "mid$(str$(da),2)"."mid$(str$(mo),2)"."mid$(str$(yr),2)',
  'date: "mid$(str$(yr),2)"-"right$(str$(100+mo),2)"-"right$(str$(100+da),2)'),
 ('slunce zapada:{wht}      ', 'sunset:{wht}             '),
 ('astronomicka noc:{wht}   ', 'astronomical night:{wht} '),
 ('thenprint"od ";', 'thenprint"from ";'),
 ('"                    do "', '"                    to   "'),
 ('mesic zapada:{wht}       ', 'moonset:{wht}            '),
 ('tx$="nezapada"', 'tx$="does not set"'),
 ('tx$="nenastava"', 'tx$="none"'),
 ('datum, cas a misto pozorovani', 'date, time and place of observation'),
 ('(return = ponechat puvodni hodnotu)', '(return = keep the current value)'),
 ('"den           "', '"day           "'),
 ('"mesic         "', '"month         "'),
 ('"rok           "', '"year          "'),
 ('"hodina        "', '"hour          "'),
 ('"minuta        "', '"minute        "'),
 ('"pasmo (utc+)  "', '"zone (utc+)   "'),
 ('"zem. sirka    "', '"latitude      "'),
 ('"zem. delka    "', '"longitude     "'),
 ('{cyn}ovladani:', '{cyn}controls:'),
 ('kurzor/joy  {yel}otaceni pohledu', 'cursor/joy  {yel}rotate the view'),
 ('+ -         {yel}priblizit / oddalit', '+ -         {yel}zoom in / out'),
 ('s v j z     {yel}sever/vychod/jih/zapad', 'n e s w     {yel}north/east/south/west'),
 (', .         {yel}cas -/+ 10 minut', ', .         {yel}time -/+ 10 minutes'),
 (': ;         {yel}cas -/+ 1 hodina', ': ;         {yel}time -/+ 1 hour'),
 ('return      {yel}prepocitat planety (*)', 'return      {yel}recompute planets (*)'),
 ('c n m       {yel}cary/nazvy/messier', 'c l m       {yel}lines/labels/messier'),
 ('h i         {yel}hledat / casy zapadu', 'f i         {yel}find / sunset times'),
 ('d q         {yel}nove datum / konec', 'd q         {yel}new date / quit'),
]
for a, c in T:
    assert a in b, a
    b = b.replace(a, c)
open(os.path.join(D, 'planet_en.bas'), 'w').write(b)
