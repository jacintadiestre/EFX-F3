/*=================================================================
Project:		Condiciones financieras en base microdatos (EFX F3)
This do:		Limpieza inicial base
Modif d/m/y:	27/10/2022	
Author:			Jacinta Diestre
Contact:		jacinta.diestre@gmail.com
SERVIDOR 
===================================================================*/	

/*=================================================================
Notas generales
En este dofile realizamos la limpieza de la base de microdatos que utilizaremos para realiazara el análisis de condiciones financieras.
Se abordan problemas de formato, duplicados, junto con definir la estructura de los créditos decrecientes.
===================================================================*/	

/*=================================================================
Directorio dofile EFX F3

1. Fija directorios
   1.1 Global países
   1.2 Directorio usuario
   1.3 Log 
   
2. Limpieza de base
   2.1 Base inicial (raw)
   2.2 Revisión tipo de datos y cantidad de observaciones
   2.3 Revisión Nulos
   2.4 Revisión Duplicados
   2.5 Archivo datos duplicados eliminados
   2.6 Revisión periodos de información duplicados en un ID
   2.7 Archivo periodos de información duplicados en un ID
3. Base crédito Decreciente de personas juridicas
   3.1 Selección de observaciones
   3.2 Selección variables de interés
   3.3 Arreglo variables de fechas %td
   3.3 Base créditos decrecientes personas jurídicas
   
4. Revisión créditos Decrecientes por identificador único
   4.1 Plazo del crédito
     4.1.1 Plazos nulos o iguales a 0
     4.1.2 Meses entre la fecha de otorgamiento y vencimiento.
     4.1.3 Cuenta_meses negativos, ceros o menores a 1 mes.
     4.1.4 Comparación plazo y cuenta_meses
	 4.1.5 Variación plazo en ID_UNICO_CRED_str
     4.1.6 Archivo problemas con las fechas y plazo
  4.2 Monto del crédito
     4.2.1 Montos nulos o iguales a 0
     4.2.2 Variación monto en ID_UNICO_CRED_str
	 4.2.3 Monto que pasa a cero
     4.2.4 Archivo problemas con monto
  4.3 Cuota del crédito
     4.3.1 Cuotas nulas o iguales a 0
     4.3.2 Variación cuota en ID_UNICO_CRED_str
     4.3.3 Archivo problemas cuota
	 
5.Revisión Fechas de otorgamiento y vencimiento 
  5.1 Fecha de otorgamiento y vencimiento nulas 
  5.2 Periodos fecha de otorgamiento
  5.3 Fecha de otorgamiento Antiguas
===================================================================*/	

* Inicio do file
version 17.0
clear
clear mata
clear matrix
set more off, permanently
cap log close
* set dp comma 
parallel setclusters 8

/*==============================================================================
1. Fija directorios
================================================================================*/
*-------------------------------------------------------------------------------
* 1.1 Global países
* Es lo primero que hay que hacer para que el directorio tome la global.
*-------------------------------------------------------------------------------
* Asignar país
 global pais "ES"
*-------------------------------------------------------------------------------
* 1.2 Directorio usuario local
* Para OneDrive
* /Users/jacinta/Library/CloudStorage/OneDrive-Personal/EFX F3/
*-------------------------------------------------------------------------------
global dir "/home/alejandrot/private/EFX F3"
global data "$dir/data"
global data_int "$data/int/SLV"
global logs "$dir/logs/SLV"

*-------------------------------------------------------------------------------
* 1.3 Log 
* abrir o crear uno nuevo
*-------------------------------------------------------------------------------
* 
cap log using "$logs/EFX F3 SLV 010 010 Limpieza Base completa.smcl"
cap log using "$logs/EFX F3 SLV 010 010 Limpieza Base completa.smcl", replace

* 
*===============================================================================
* 2.Limpieza de base
*===============================================================================
*-------------------------------------------------------------------------------
* 2.1 Base inicial (raw)
*-------------------------------------------------------------------------------
* utilizamos la base inicial asociada al país 
use "$data/raw/SLV/EFX F3 SLV 011 raw 201810 202109.dta", clear 
*-------------------------------------------------------------------------------
* 2.2 Revisión tipo de datos y cantidad de observaciones
*-------------------------------------------------------------------------------
count //16.654.888
*codebook
*outreg2 using summarystats, replace sum(detail) excel

*-------------------------------------------------------------------------------
* 2.3 Revisión Nulos
*-------------------------------------------------------------------------------
*Porcentaje de valores missing
mdesc 

*-------------------------------------------------------------------------------
* 2.4 Revisión Duplicados
*-------------------------------------------------------------------------------
* Creamos un reporte de los datos duplicados en la base.
* Consideramos duplicidad en la totalidad de las variables. 
duplicates report
duplicates tag, gen(dup)
tab dup, m 


*-------------------------------------------------------------------------------
* 2.5 Archivo datos duplicados eliminados
*-------------------------------------------------------------------------------
* Exportamos en un csv todas observaciones que presentan duplicados. 
preserve
bys ID_UNICO_CRED_str: egen duplicado=max(dup)
keep if duplicado>0
export delimited using  "$data/raw/SLV/EFX F3 SLV - duplicados.csv", delimiter("|") replace
restore

* Volvemos a la base original y eliminamos todas las observaciones duplicadas. 
duplicates drop 
drop dup 

*-------------------------------------------------------------------------------
* 2.6 Revisión Duplicados ID_UNICO_CRED_str + periodo_infor
*-------------------------------------------------------------------------------
duplicates report ID_UNICO_CRED_str periodo_informacion
duplicates tag ID_UNICO_CRED_str periodo_informacion, gen(dup)
tab dup, m 

*-------------------------------------------------------------------------------
* 2.7 Archivo de datos duplicados
*-------------------------------------------------------------------------------
preserve
bys ID_UNICO_CRED_str: egen duplicado_fecha=max(dup)
keep if duplicado_fecha>0
export delimited using "$data/EFX F3 ES 010 010 Limpieza Base - periodo_infor_duplicado_mismo_ID_UNICO.csv", delimiter("|") replace
restore
*===============================================================================
* 3. Base crédito Decreciente de personas juridicas
*===============================================================================
*-------------------------------------------------------------------------------
* 3.1 Selección de observaciones
*-------------------------------------------------------------------------------
tab tipo_prestamo , m 
* Hay dos valores 1 y 2 pero no aparecen los labels
tab idtipo_persona, m 

keep if tipo_prestamo == "CREDITO DECRECIENTE"

*Total de observaciones de creditos decrecientes 2.764.463
count

*-------------------------------------------------------------------------------
* 3.2 Selección variables de interés
*-------------------------------------------------------------------------------
keep idpersona ID_UNICO_CRED_str id_acreedor referencia_unica idtipo_persona sector_empresa tamanio_empresa otorgante_publico_privado regulada calificacion_riesgo fecha_otorgamiento fecha_vencimiento fecha_inicio_mora periodo_informacion monto saldo plazo cuota saldo_mora tipo_credito tipo_prestamo fecha_inicio_mora estado_credito sexo

*-------------------------------------------------------------------------------
* 3.3 Variables de fechas a formato %td
* Transformar las variables asociadas a priodos de info en formato %td (to date)
*-------------------------------------------------------------------------------
tostring periodo_informacion, gen(periodo_infor)

gen year  = substr(periodo_infor, 1, 4)
gen month = substr(periodo_infor, 5, 6)

replace fecha_vencimiento = substr(fecha_vencimiento, 1, 10)
replace fecha_otorgamiento = substr(fecha_otorgamiento, 1, 10)
replace fecha_inicio_mora = substr(fecha_inicio_mora, 1, 10)

gen fecha_vencimiento_1 =date(fecha_vencimiento , "YMD")
gen fecha_otorgamiento_1 =date(fecha_otorgamiento , "YMD")
gen fecha_mora_1 = date(fecha_inicio_mora, "YMD")

drop fecha_vencimiento fecha_otorgamiento fecha_inicio_mora 
rename fecha_vencimiento_1 fecha_vencimiento
rename fecha_otorgamiento_1 fecha_otorgamiento
rename fecha_mora_1 fecha_mora

format fecha_vencimiento %td
format fecha_otorgamiento %td
format fecha_mora %td

*-------------------------------------------------------------------------------
* 3.4 Base créditos decrecientes personas jurídicas
*-------------------------------------------------------------------------------
save "$data/EFX F3 $pais 010 010 Limpieza Base.dta", replace

*===============================================================================
* 4. Revisión créditos Decrecientes por identificador
* Variable: ID_UNICO_CRED_str
*===============================================================================
use "$data/EFX F3 $pais 010 010 Limpieza Base.dta", clear

* Variable de la cantidad de observaciones por id único y conteo por id
sort ID_UNICO_CRED_str periodo_informacion
bysort ID_UNICO_CRED_str: gen N=_N
bysort ID_UNICO_CRED_str: gen n=_n

*-------------------------------------------------------------------------------
* 4.1 Plazo del crédito
*-------------------------------------------------------------------------------
*-------------------------------------------------------------------------------
* 4.1.1 Plazos nulos o iguales a 0
*-------------------------------------------------------------------------------
count if plazo==. //94
count if plazo==0 //10.461                                                                         

*-------------------------------------------------------------------------------
* 4.1.2 Meses entre la fecha de otorgamiento y vencimiento.
*-------------------------------------------------------------------------------
gen cuenta_meses = datediff(fecha_otorgamiento,fecha_vencimiento, "day")
replace cuenta_meses = cuenta_meses/30.4
summ cuenta_meses, detail 
label var cuenta_meses "Meses entre fecha_otorgamiento y fecha_vencimiento"


* Revisar id "2137131-10114140435         -4755-2019-02-22 00:00:00"

*-------------------------------------------------------------------------------
* 4.1.3 Cuenta_meses negativos, ceros o menores a 1 mes
*-------------------------------------------------------------------------------
count if cuenta_meses<0 //3
count if cuenta_meses==0 //555
count if cuenta_meses<1 & cuenta_meses>0 //11,421
replace cuenta_meses=round(cuenta_meses)

*-------------------------------------------------------------------------------
* 4.1.4 Comparación plazo y cuenta_meses
*-------------------------------------------------------------------------------
* Definimos un criterio de 1 mes de diferencia por los redondeos
gen dif_plazos = cuenta_meses - plazo
gen plazo_fechas = (dif_plazos == 0 |dif_plazos == 1|dif_plazos == -1) //94 casos no calzan

label var plazo_fechas "Plazo y cuenta_meses iguales"

*-------------------------------------------------------------------------------
* 4.1.5 Variación plazo en ID_UNICO_CRED_str
*-------------------------------------------------------------------------------

bysort ID_UNICO_CRED_str: egen sd_plazo = sd(plazo)
gen var_plazo = sd_plazo^2
count if var_plazo>0 // 433.398 cantidad de observaciones con variación en plazo

*En el caso que el ID_UNICO_CRED_str tiene sólo una observación la varianza se lleva a nulo.
*Definir si los mantenemos o no en la base de datos - Los identificamos y luego les asignamos un valor de 0.
tab N if var_plazo==., m 

replace var_plazo = 0 if var_plazo==.

bysort ID_UNICO_CRED_str (n): gen dif_plazo = plazo - plazo[_n-1] if n!=1

*-------------------------------------------------------------------------------
* 4.1.6 Archivo problemas con las fechas y plazo
*-------------------------------------------------------------------------------
gen probl_plazo = (fecha_vencimiento==. | cuenta_meses<=1 | dif_plazos==0 | var_plazo>0 )
bys ID_UNICO_CRED_str: egen probl_plazo_id = max(probl_plazo)

count if probl_plazo_id==1
if r(N)>0{
preserve
keep if probl_plazo_id==1
export delimited using "$data/EFX F3 $pais 010 010 Limpieza Base - dif plazo y fechas venc-otorg.csv", delimiter("|") replace
restore
}

drop cuenta_meses dif_plazos
*-------------------------------------------------------------------------------
* 4.2 Monto del crédito
*-------------------------------------------------------------------------------

*-------------------------------------------------------------------------------
* 4.2.1 Montos nulos o iguales a 0
*------------------------------------------------------------------------------- 
count if monto==. // 0
count if monto==0 //3.227

*-------------------------------------------------------------------------------
* 4.2.2 Variación monto en ID_UNICO_CRED_str
*-------------------------------------------------------------------------------  
bysort ID_UNICO_CRED_str: egen var_monto = sd(monto)
* En los casos en que hay solo 
replace var_monto = var_monto^2
count if var_monto>0 // 485,006 cantidad de observaciones con variación en montos

* Revisar "1000174362-09201900017600      -6358-2020-01-17 00:00:00"

replace var_monto=0 if var_monto<2
*Ver qué hacer con las observaciones únicas
tab N if var_monto==., m 
replace var_monto= 0 if var_monto==.

bysort ID_UNICO_CRED_str (n): gen dif_monto = monto - monto[_n-1] if n!=1
gen dif_monto_abs=abs(dif_monto)
count if (dif_monto <= 1000  & var_monto > 0) 
* Definir un epsilon de tolerancia

*-------------------------------------------------------------------------------
* 4.2.3 Monto que pasa a cero
*-------------------------------------------------------------------------------  
gen monto_pasa0 = (dif_monto == monto[_n-1] & monto[_n-1]!=0)
label var monto_pasa0 "Obs con montos positivos que pasan a cero"

*-------------------------------------------------------------------------------
* 4.2.4 Archivo problemas con monto
*-------------------------------------------------------------------------------  
gen probl_monto =  (monto==. | monto==0| var_mont>0 | monto_pasa0==1)
* Definir epsilon de tolerancia
bys ID_UNICO_CRED_str: egen probl_monto_id = max(probl_monto)

count if probl_monto_id==1
if r(N)>0{
preserve
keep if probl_monto_id==1
export delimited using "$data/EFX F3 $pais 010 010 Limpieza Base - probl monto.csv", delimiter("|") replace
restore
}
     
	 
*-------------------------------------------------------------------------------
* 4.3 Cuota del crédito
*-------------------------------------------------------------------------------
*-------------------------------------------------------------------------------
* 4.3.1 Cuotas nulas o iguales a 0
*------------------------------------------------------------------------------- 
count if cuota==. // 0
count if cuota==0 //118.792

*-------------------------------------------------------------------------------
* 4.3.2 Variación cuota en ID_UNICO_CRED_str
*-------------------------------------------------------------------------------  
bysort ID_UNICO_CRED_str: egen sd_cuota = sd(cuota)
* En los casos en que hay solo 
gen var_cuota  = sd_cuota^2
count if var_cuota >0 // 485.115 cantidad de observaciones con variación en montos

* Ver qué hacer con las observaciones únicas
tab N if var_cuota ==., m 

replace var_cuota = 0 if var_cuota ==.
count if var_cuota>0 //1.853.187 

bysort ID_UNICO_CRED_str (n): gen dif_cuota = cuota - cuota[_n-1] if n!=1
replace  dif_cuota = abs(dif_cuota)
summ dif_cuota, detail

* Definimos un épsilon de tolerancia por el redondeo de las cuotas
count if (dif_cuota > 0.0 & dif_cuota < 0.2 & sd_cuota > 0)  
* Ver las desviaciones para definir un umbral 
* caso "34757-99-420-132774       -4715-2014-09-24 00:00:00"
*-------------------------------------------------------------------------------
* 4.3.3 Archivo problemas cuota
*-------------------------------------------------------------------------------  
gen probl_cuota =  (cuota==. | cuota==0 | var_cuota>0 )
replace probl_cuota = 0 if (dif_cuota>0.0 & dif_cuota<0.2 & var_cuota>0)

bys ID_UNICO_CRED_str: egen probl_cuota_id = max(probl_cuota)

count if probl_cuota_id==1
if r(N)>0{
preserve
keep if probl_cuota_id==1
export delimited using "$data/EFX F3 $pais 010 010 Limpieza Base - probl cuota.csv", delimiter("|") replace
restore
}
replace probl_cuota =  (cuota==. | cuota==0 | sd_cuota>0 )
*===============================================================================
* 5. Fechas de otorgamiento y vencimiento 
*===============================================================================
*-------------------------------------------------------------------------------
* 5.1 Fecha de otorgamiento y vencimiento nulas 
*-------------------------------------------------------------------------------  
* Fecha de otorgamiento NA  En esta base no me aperecen iguales a Nulo REVISAR!
count if fecha_otorgamiento==.	| fecha_vencimiento==.

*-------------------------------------------------------------------------------
* 5.2 Fecha de otorgamiento Antiguas
*-------------------------------------------------------------------------------  

gen year_otorg = year(fecha_otorgamiento)

gen periodo_otorg =1 if year_otorg >= 2022
replace periodo_otorg =2 if year_otorg < 2022 & year_otorg >= 1990
replace periodo_otorg =3 if year_otorg < 1990 & year_otorg >= 1970
replace periodo_otorg =4 if year_otorg < 1970 & year_otorg >= 1930
replace periodo_otorg =5 if year_otorg < 1930 & year_otorg >= 1900
replace periodo_otorg =9 if year_otorg < 1900 

* Esto está mal porque el periodo de información no tiene día para comparar con el resto de las fechas
gen periodo_infor_date =date(periodo_infor , "YM")

* Asignamos labels a los valores de la variable, para evitar los string
label define periodo_otorg_l 1 "fecha de otorgamiento posterior a 2022" 2 "fecha de otorgamiento entre 2022 y 1990" 3 "fecha de otorgamiento entre 1990 y 1970" 4 "fecha de otorgamiento entre 1970 y 1930" 5 "fecha de otorgamiento entre 1930 y 1900" 9 "fecha de otorgamiento año mal tabulado"
label values periodo_otorg periodo_otorg_l

count if periodo_otorg==4 |periodo_otorg==5  

*-------------------------------------------------------------------------------
* 5.2 Fecha de otorgamiento mal definidas
* fechas previas a 1900
*-------------------------------------------------------------------------------  
count if periodo_otorg==9

*-------------------------------------------------------------------------------
* 5.3 Fecha de otorgamiento previas a la fecha de reporte
*-------------------------------------------------------------------------------  
count if periodo_infor_date<fecha_otorgamiento

*-------------------------------------------------------------------------------
* 5.4 Fecha de otorgamiento posterior a fecha de vencimiento
*-------------------------------------------------------------------------------  
count if fecha_vencimiento<fecha_otorgamiento

*-------------------------------------------------------------------------------
* 5.5 Errores Plazos Mora
*------------------------------------------------------------------------------- 
gen probl_mora=0 if fecha_mora > fecha_otorgamiento
replace probl_mora = 0 if fecha_mora > fecha_vencimiento 
replace probl_mora = 0 if fecha_mora == fecha_otorgamiento
replace probl_mora = 0 if fecha_mora == fecha_vencimiento
replace probl_mora = 1 if fecha_mora < fecha_otorgamiento
replace probl_mora = 1 if fecha_mora > fecha_vencimiento
count if probl_mora ==1


*===============================================================================
* 6. Credito decreciente comportamiento ideal tipo persona = 2
*==============================================================================
*-------------------------------------------------------------------------------
* 6.1 Filtro por personas jurídicas
*-------------------------------------------------------------------------------  
tab idtipo_persona, m
keep if idtipo_persona == 2  
count //10.591

*-------------------------------------------------------------------------------
* 6.2 Revisión que se incluyan todos los periodos de información para un mismo 
*ID_UNICO_CRED_str
*-------------------------------------------------------------------------------  

gen periodo_infor_num = real(periodo_infor)
bysort ID_UNICO_CRED_str (n): gen dif_periodo_infor_num = periodo_infor_num  - periodo_infor_num[_n-1] if n!=1
tab dif_periodo_infor_num, m

* Una referencia única se inica con un missing. La dif entre meses consecutivos es == 1
* mientras que el paso de un año a otro deberia ser == 89. Si es ==0 la ref tiene un perdiodo "duplicado"
* los valores distinos a los mencionados indican la cantida dde periodos que se "saltea"

preserve
keep if ID_UNICO_CRED_str == "2230688-000704345390        -4540-2018-05-29 00:00:00"
*export delimited using "equifax/EFX F3 ES 010 010 Limpieza Base - periodo_infor_duplicado_mismo_ID_UNICO.csv", delimiter("|") replace
restore

* Tomamos los ID_UNICO_CRED_str completos -> y los agrupamos con una dummy si es ==1 entonces TIENE PERIODOS SECUENCIALES

bys ID_UNICO_CRED: gen plazo_secuencial= (dif_periodo_infor_num ==1 | dif_periodo_infor_num ==89 | dif_periodo_infor_num ==.)
bys ID_UNICO_CRED: egen plazo_secuencial_id = min(plazo_secuencial)


* armamos el documento complementario para revisar los que no tienen plazo secuencial

preserve
keep if plazo_secuencial_id == 0
*export delimited using "equifax/EFX F3 ES 010 010 Limpieza Base - plazo_secuencial_inc_.csv", delimiter("|") replace
restore


*-------------------------------------------------------------------------------
* 6.3 Revision de comportamiento de saldo
*-------------------------------------------------------------------------------  

sort ID_UNICO_CRED_str periodo_informacion
bys ID_UNICO_CRED_str: gen dif_saldo = saldo-saldo[_n-1]
order dif_saldo, after(saldo)


** dummy que toma valor 1 cuando el saldo decrete para ID_UNICO_CRED_str y 0 si no lo hace
gen saldo_cae = (dif_saldo<0) if dif_saldo!=., after(dif_saldo) // 1 = cae el saldo, .=primera obs por ref, 0=saldo crece o se mantiene 
bys ID_UNICO_CRED_str: egen saldo_siempre_cae_id = min(saldo_cae) // min==0: algun a vez el saldo crece o se mantiene, min==1: el saldo siempre cae, min=-.: hay un solo registro


order saldo_siempre_cae_id, after(saldo_cae)
tab saldo_siempre_cae_id,m

if r(N)>0{
preserve
keep if idtipo_persona == 2   //10.591
*export delimited using "$data/EFX F3 $pais 010 010 Limpieza Base - probl fechas.csv", delimiter("|") replace
restore
}


*-------------------------------------------------------------------------------
* 6.4 Archivo problemas fechas
*-------------------------------------------------------------------------------  
gen probl_fecha =  (fecha_otorgamiento==. | fecha_vencimiento==. | periodo_otorg==4 |periodo_otorg==5 | periodo_otorg==9 | (fecha_otorgamiento>periodo_infor_date) | (fecha_otorgamiento>fecha_vencimiento) | probl_mora==1)

bys ID_UNICO_CRED_str: egen probl_fecha_id = max(probl_fecha)

count if probl_fecha_id==1
if r(N)>0{
preserve
keep if probl_fecha_id==1
export delimited using "$data/EFX F3 $pais 010 010 Limpieza Base - probl fechas.csv", delimiter("|") replace
restore
}

*===============================================================================
* 6. Revisión Tasa de interés
*===============================================================================

preserve
import delimited "$data/Tasa_interes_el_salvador.csv", clear
duplicates report
duplicates drop
* Cambiamos el formato de la tasa de interés de string a numeric. 
* Eliminando el último caracter que es el %.
* Los valores en este campo son tasas de interés en %
gen tasa_inte2 = tasa_inte
replace tasa_inte = substr(tasa_inte, 1, strlen(tasa_inte) - 1)
destring tasa_inte, replace

replace fecha_otorgamiento = substr(fecha_otorgamiento, 1, 10)
gen fecha_otorgamiento_1 =date(fecha_otorgamiento , "YMD")
drop fecha_otorgamiento
rename fecha_otorgamiento_1 fecha_otorgamiento
format fecha_otorgamiento %td
desc
*Tenemos que guardar la base antes de hacer el merge
save "$data/Tasa_interes_el_salvador_sd", replace
restore
* La base de datos de las tasas de interés tienen más de un valor para la combinación "idpersona", "id_acreedor","fecha_otorgamiento"
*===============================================================================
* 9. Guardamos la base de datos final con la tasa de interés.
*===============================================================================

* Guardamos la base de las tasas de interés sin duplicados
merge m:1 idpersona id_acreedor referencia_unica fecha_otorgamiento using  "$bases/Tasa_interes_el_salvador_sd", keep(3) gen(base_tasa)
* Reviso las tasas de interés 
* El máximo valor de la tasa de interés es de 77,68%.
* Revisé las tasas de interés con el dato original en string y aparecen con %.
egen valores_tasas = cut(tasa_inte), at(0,5,10,20,30,40,50,60,70,80,90,100)
graph box tasa_inte, over(valores_tasas) ytitle("Tasas de interés por tramo")
graph box tasa_inte, over(calificacion_riesgo)
drop tasa_inte2 
save "$data/EFX F3 050 010 2 muestra SLV pod decreciente.dta", replace

log close



*-------------------------------------------------------------------------------
* 3.4 Identificamos los créditos que están correctamente reportados
* Esto implica que las tres variaciones anteriores iguales a 0
* Revisar: En este caso nos quedamos con todos los créditos que tienen una observación, porque le asignamos varianza 0 previamente
*-------------------------------------------------------------------------------
* Cambio en los nombres de las variables 
rename (variacion_en_monto variacion_en_cuota variacion_en_plazo) (varianza_monto varianza_cuota varianza_plazo)

* Identificamos los ID_UNICO_CRED_str que se comportan correctamente.

* Generamos una dummy para identificar los casos en las que las 3 variables tienen varianza igual a 0.
gen variacion = (varianza_monto == 0 & varianza_cuota == 0 & varianza_plazo == 0)

tab variacion, m //Se ven muy pocos casos bien comportados. Ver la base construida por Facundo 862903
count if variacion==1

keep if variacion == 1
* Exportamos los datos en un csv
* Revisamos si hay duplicados 
duplicates report
duplicates drop 
export delimited using "$data/EFX F3 $pais 010 010 - Creditos decrecientes.csv", delimiter("|") replace
save "$data/EFX F3 $pais 010 010 - Creditos decrecientes", replace
*reditos decrecientes", replace

