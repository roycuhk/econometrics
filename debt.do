///《城投债为何持续增长：基于新口径的实证分析》基准回归结果

clear
cd C:\Users\zjumilesark\Desktop\财贸经济修改稿
use regdata.dta, clear
set matsize 10000

*表3 主要变量的描述性统计
logout, save(table3) word dec(4) replace: ///
tabstat d_debt debt1 debt2 debt3 r_ygz d_ygz auto1 auto2 d_age stress_realgdppc stress_urb stress_sec stress_inv lnrealgdppc land lnpopden, ///
stats(N mean sd min p50 max) c(s) f(%9.4f)

*表4 晋升压力对发债概率的影响
probit d_debt d_age L.lnrealgdppc L.land L.lnpopden if fxns>0, vce(cluster citycode) nolog
est store m1
logit d_debt d_age L.lnrealgdppc L.land L.lnpopden if fxns>0, vce(cluster citycode) nolog
est store m2
xtlogit d_debt d_age L.lnrealgdppc L.land L.lnpopden i.year if fxns>0, fe nolog
est store m3
esttab m1 m2 m3 using table4, rtf replace pr2(%9.4f) b(%9.4f) se(%7.4f) star(* 0.1 ** 0.05 *** 0.01) nogaps

*表5 晋升压力对新增债务的影响
xtset citycode year
forvalues i=1(1)3 {
  xtreg debt`i' d_age L.lnrealgdppc L.land L.lnpopden i.year i.provcode#i.year if fxns>0, fe vce(cluster citycode)
  est store m_`i'
  }
outreg2 [m_1 m_2 m_3] using table5, word dec(4) replace

*表6 晋升压力和发展压力对新增债务的影响
local varlist "realgdppc sec urb inv"
foreach var of local varlist {
  xtreg debt1 inter_`var' d_age L.stress_`var' L.lnrealgdppc L.land L.lnpopden i.year i.provcode#i.year if fxns>0, fe vce(cluster citycode)
  est store m_`var'
  }
outreg2 [m_realgdppc m_sec m_urb m_inv] using table6-1, word dec(4) replace

xtset citycode year
local varlist "realgdppc sec urb inv"
foreach var of local varlist {
  xtreg debt2 inter_`var' d_age L.stress_`var' L.lnrealgdppc L.land L.lnpopden i.year i.provcode#i.year if fxns>0, fe vce(cluster citycode)
  est store m_`var'
  }
outreg2 [m_realgdppc m_sec m_urb m_inv] using table6-2, word dec(4) replace

local varlist "realgdppc sec urb inv"
foreach var of local varlist {
  xtreg debt3 inter_`var' d_age L.stress_`var' L.lnrealgdppc L.land L.lnpopden i.year i.provcode#i.year if fxns>0, fe vce(cluster citycode)
  est store m_`var'
  }
outreg2 [m_realgdppc m_sec m_urb m_inv] using table6-3, word dec(4) replace
