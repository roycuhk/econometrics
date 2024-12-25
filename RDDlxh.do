
use regdata0.dta,clear

rename hischshr1520f Y
rename i94 T
gen X = vi1*100
replace Y = Y*100

cls


*===================================*
*             断点图示              *
*===================================*


twoway (scatter Y X,  mcolor(black) msize(vsmall) xline(0, lcolor(black))), ///
       graphregion(color(white)) ytitle(Outcome) xtitle(Score)
	   
rdplot Y X, nbins(20 20) binselect(es) graph_options(graphregion(color(white)) ///
       xtitle(Score) ytitle(Outcome)) 
	   
rdplot Y X, nbins(20 20) binselect(qs) graph_options(graphregion(color(white)) ///
       xtitle(Score) ytitle(Outcome))
	   
rdplot Y X, binselect(es) graph_options(graphregion(color(white)) ///
       xtitle(Score) ytitle(Outcome))
	   
rdplot Y X, binselect(qs) graph_options(graphregion(color(white)) ///
       xtitle(Score) ytitle(Outcome))
	   
rdplot Y X, binselect(esmv) graph_options(graphregion(color(white)) ///
       xtitle(Score) ytitle(Outcome))
	   
rdplot Y X, binselect(qsmv) graph_options(graphregion(color(white)) ///
       xtitle(Score) ytitle(Outcome))
	   	   
	   
*===================================*
*              点估计               *
*===================================*

********** 分段回归方法 *********

reg Y X if X < 0 & X >= -20
matrix coef_left = e(b)
local intercept_left = coef_left[1, 2]
reg Y X if X >= 0 & X <= 20
matrix coef_right = e(b)
local intercept_right = coef_right[1, 2]
local difference = `intercept_right' - `intercept_left'

dis "The RD estimator is `difference'"


********** 交互项回归方法 *********

gen T_X = X * T
reg Y X T T_X if X >= -20 & X <= 20

********** 使用三角核函数 *********

gen weights = .
replace weights = (1 - abs(X / 20)) if X < 0 & X >= -20
replace weights = (1 - abs(X / 20)) if X >= 0 & X <= 20

reg Y X [aw = weights] if X < 0 & X >= -20
matrix coef_left = e(b)
local intercept_left = coef_left[1, 2]
reg Y X [aw = weights] if X >= 0 & X <= 20
matrix coef_right = e(b)
local intercept_right = coef_right[1, 2]
local difference = `intercept_right' - `intercept_left'

dis "The RD estimator is `difference'"

********** 使用rdrobust命令的点估计 **********

rdrobust Y X, kernel(uniform) p(1) h(20)
rdrobust Y X, kernel(triangular) p(1) h(20)
rdrobust Y X, kernel(triangular) p(2) h(20)

********** 最优带宽的选择 **********

rdbwselect Y X, kernel(triangular) p(1) bwselect(mserd)
rdbwselect Y X, kernel(triangular) p(1) bwselect(msetwo)

rdrobust Y X, kernel(triangular) p(1) bwselect(mserd)
ereturn list

rdrobust Y X, p(1) kernel(triangular) bwselect(mserd)
local bandwidth = e(h_l)
rdplot Y X if abs(X) <= `bandwidth', p(1) h(`bandwidth') kernel(triangular)

********** 统计推断 **********

rdrobust Y X, kernel(triangular) p(1) bwselect(mserd)
rdrobust Y X, kernel(triangular) p(1) bwselect(mserd) all

rdrobust Y X, kernel(triangular) p(1) bwselect(cerrd)

rdbwselect Y X, kernel(triangular) p(1) all


********** 协变量调整 **********

global covariates "vshr_islam1994 partycount lpop1994 merkezi merkezp subbuyuk buyuk"

rdbwselect Y X, covs($covariates) p(1) kernel(triangular) bwselect(mserd) scaleregul(1)

rdrobust Y X, covs($covariates) p(1) kernel(triangular) bwselect(mserd) scaleregul(1)


********** 聚类稳健标准误 **********

rdrobust Y X, p(1) kernel(triangular) bwselect(mserd) scaleregul(1) vce(nncluster prov_num)

global covariates "vshr_islam1994 partycount lpop1994 merkezi merkezp subbuyuk buyuk"
rdrobust Y X, covs($covariates) p(1) kernel(triangular) bwselect(mserd)scaleregul(1) vce(nncluster prov_num)


*===================================*
*           有效性检验              *
*===================================*

********** 前定协变量和安慰剂结果变量 **********

foreach v in lpop1994 partycount vshr_islam1994 buyuk merkezp merkezi{
  rdplot `v' X
}

foreach v in lpop1994 partycount vshr_islam1994 buyuk merkezp merkezi{
  rdrobust `v' X
}

mat A = J(6,6,.)
local j = 1
local i = 1
foreach v in lpop1994 partycount vshr_islam1994 buyuk merkezp merkezi{
  qui rdrobust `v' X
  mat A[`i',`j'] = e(h_l)
  mat A[`i',`j'+1] = e(tau_cl)
  mat A[`i',`j'+2] = e(pv_cl)
  mat A[`i',`j'+3] = e(ci_l_cl)
  mat A[`i',`j'+4] = e(ci_r_cl)
  mat A[`i',`j'+5] = e(N_h_l) + e(N_h_r)
  local j = 1
  local i = `i' + 1
}  

mat rownames A = lpop1994 partycount vshr_islam1994 buyuk merkezp merkezi
mat colnames A = Bw Est p-value CI_l CI_r Obs

matlist A

********** 驱动变量的密度 **********

bitesti 100 53 1/2

rddensity X

********** 安慰剂断点 **********

rdrobust Y X if X >= 0, c(1)

mat A = J(7,8,.)
local i = 1

forvalues c = -3/3{
  if `c'>0{
    local condition "if X > 0"
  }
  else if `c'== 0{
    local condition ""
  }
  else{
    local condition "if X < 0"
  }
  dis "此时选择的断点为 c = `c'"
  qui rdrobust Y X,c(`c')
  
  mat A[`i',1] = `c'
  mat A[`i',2] = e(h_l)
  mat A[`i',3] =  e(tau_cl)
  mat A[`i',4] =  e(pv_cl)
  mat A[`i',5] =  e(ci_l_cl)
  mat A[`i',6] =  e(ci_r_cl)
  mat A[`i',7] =  e(N_h_l)
  mat A[`i++',8] =  e(N_h_r)
}

mat colnames A = Cutoff Bw Est p-value CI_l CI_r Obs_left Obs_right
matlist A


********** 断点附近观测值的敏感性 **********

rdrobust Y X if abs(X) >= 0.3

mat A = J(6,7,.)
local i = 1

forvalues r = 0(0.1)0.5{
  qui rdrobust Y X if abs(X) >= `r'
  
  mat A[`i',1] = `r'
  mat A[`i',2] = e(h_l)
  mat A[`i',3] =  e(tau_cl)
  mat A[`i',4] =  e(pv_cl)
  mat A[`i',5] =  e(ci_l_cl)
  mat A[`i',6] =  e(ci_r_cl)
  mat A[`i++',7] =  e(N_h_l)+ e(N_h_r)
}

mat colnames A = Dount-Radius Bw Est p-value CI_l CI_r Obs
matlist A


********** 带宽选择的敏感性 **********

qui rdrobust Y X
local h2 = 2*e(h_l)
local h3 = 3*e(h_l)

rdrobust Y X
rdrobust Y X,h(`h2' `h2')
rdrobust Y X,h(`h3' `h3')

qui rdrobust Y X,bwselect(cerrd)
local h2 = 2*e(h_l)
local h3 = 3*e(h_l)

rdrobust Y X,bwselect(cerrd)
rdrobust Y X,h(`h2' `h2') bwselect(cerrd)
rdrobust Y X,h(`h3' `h3') bwselect(cerrd)

*=====================================*
*           绘制一些图片              *
*=====================================*

********** 绘制图3 **********

qui sum Y if X>=0
gen m_r = r(mean)
qui sum Y if X<0
gen m_l = r(mean)

drop if Y>60


twoway (scatter Y X,  mcolor(black) msize(vsmall) xline(0, lcolor(black)) ) ///
	   (line m_r X if X>=0,lcolor(red) lwidth(thin)) ///
	   (line m_l X if X<0,lcolor(red) lwidth(thin)) , ///
	   graphregion(color(white)) ytitle(Outcome) xtitle(Score) legend(off) 
	   
twoway (scatter Y X,  mcolor(black) msize(vsmall) xline(0, lcolor(black)) ) ///
	   (lpoly Y X if X>=0,lcolor(red) degree(1) lwidth(thin)) ///
	   (lpoly Y X if X<0, degree(1) lcolor(red) lwidth(thin)) , ///
	   graphregion(color(white)) ytitle(Outcome) xtitle(Score) legend(off)
