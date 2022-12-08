
cd "/Users/adf/Desktop/合成控制法材料整理/synth 合成控制法 synth"
use smoking.dta, clear 
tsset state year 

*= 合成控制法
synth cigsale retprice lnincome age15to24 beer cigsale(1975) cigsale(1980) cigsale(1988), /// 
trunit(3) trperiod(1989) xperiod(1980(1)1988) figure nested allopt keep(结果) replace


*= 在没有使用合成控制法的时候加州和其他州的人均香烟消费量的时间趋势图
use smoking.dta, clear 
bysort year: egen acigsale=mean(cigsale) if state!=3   
duplicates drop acigsale, force
drop if state==3
save dr.dta, replace
use dr.dta, clear
use smoking.dta, clear  
keep if state==3   
merge 1:1 year using dr.dta   
twoway (line cigsale year) (line acigsale year ) 


*= 画处理效应的时间趋势图
use 结果.dta, clear
gen effect=_Y_treated- _Y_synthetic
label var _time "year"
label var effect "gap in per-capita cigarette sales(in packs)"
line effect _time, xline(1989, lp(dash)) yline(0, lp(dash))


*========================================================================
*                              安慰剂检验
*========================================================================
use smoking.dta, clear 
* 对所有39个州分别进行SCM(把39个州分别作为政策影响组) 
forvalues i = 1/39 {
	qui synth cigsale retprice lnincome age15to24 beer cigsale(1975) cigsale(1980) cigsale(1988), /// 
	trunit(`i') trperiod(1989) xperiod(1980(1)1988)  keep(synth_`i', replace)     
}

* 计算处理效应
forval i=1/39{
	use synth_`i', clear
	rename _time years
	gen effect_`i' = _Y_treated-_Y_synthetic
	keep years effect_`i'
	drop if missing(years)
	save synth_`i', replace
}

* 合并数据
use synth_1.dta, clear
forval i=2/39{
	qui merge 1:1 years using synth_`i', nogenerate
}

* 计算MSPE
forval i=1/39 {
	gen sq_effect_`i'=effect_`i'^2
	egen mspe`i'=mean(sq_effect_`i') if years>=1970 & years<1989
}
drop sq_effect_*




*= 未对MSPE进行筛选
local lp
forval i=1/39 {
   local lp `lp' line effect_`i' years, lcolor(gs12) ||
}

twoway `lp' || line effect_3 years, lcolor(black) legend(off) ///
 xline(1989, lpattern(dash))   


*= 筛选干预前的MSPE小于处理地区MSPE两倍
tabstat mspe*, c(s)  
* 导出excel，判断哪些地区干预前的MSPE小于处理地区MSPE两倍
* 具体筛选表格见"筛选MSPE.xlsx"表格
local lp2
foreach i in 1 2 3 7 8 9 14 17 18 19 20 23 27 28 30 31 32 33 37 38 {
   local lp2 `lp2' line effect_`i' years , lcolor(gs12) ||
}
twoway `lp2' || line effect_3 years, lcolor(black) legend(off) ///
 xline(1989, lpattern(dash))   ylabel(-30(10) 30)



