clear all
. timer clear


// 设定随机数种子, 设置 4500 个样本观测值 //

. set seed 10
. global T = 15
. global I = 300
. set obs `=$I*$T'

// 生成 id 与时间 //
. gen i = int((_n-1)/$T )+1
. gen t = mod((_n-1),$T )+1
. tsset i t

// 随机生成每个 i d首次接受处理的时间标志, Ei 的取值在 10 和 16 之间//
. gen Ei = ceil(runiform()*7)+$T -6 if t==1
. bys i (t): replace Ei = Ei[1]

// 生成处理变量, K 为相对处理时间, D 为处理时间哑变量 //
. gen K = t-Ei
. gen D = K>=0 & Ei!=.

// 生成时间上的异质性处理效应 //
. gen tau = cond(D==1, (t-12.5), 0)

// 生成误差项 //
. gen eps = rnormal()

// 生成结果变量Y //
. gen Y = i + 3*t + tau*D + eps

// 1-1 Borusyak et al (2021) 基于插补的反事实方法 //
ssc install did_imputation
ssc install ftools
ssc install reghdfe

did_imputation Y i t Ei, allhorizons pretrends(5)
ssc install event_plot
event_plot, default_look graph_opt(xtitle("Periods since the event") ytitle("Average causal effect") title("Borusyak et al(2021) imputaion estimator") xlabel(-5(1)5) name(BJS, replace)) together
 
 /* 1-2 De Chaisemartin 和 D‘Haultfoeuille (2020) 提出通过加权计算两种处理效应的值得到平均处理效应的无偏估计，这两种处理效应为：

 t-1期未受处理而 t 期受处理的组与两期都未处理的组的平均处理效应；t-1期受处理而t 期未受处理的组与两期都受处理的组的平均处理效应 */
 ssc install did_multiplegt, replace
 did_multiplegt Y i t D, robust_dynamic dynamic(5) placebo(5) longdiff_placebo breps(100) cluster(i)
 
/* 1-3 Callaway 和 SantAnna (2021) 将 t 期以前从未受处理的组作为控制组进行估计 */
// 生成日期变量，从未受处理的组取值为 0
. gen gvar = cond(Ei>15, 0, Ei)
ssc install csdid
ssc install drdid
. csdid Y, ivar(i) time(t) gvar(gvar) agg(event)

event_plot e(b)#e(V), default_look graph_opt(xtitle("Periods since the event") ytitle("Average causal effect") ///
 xlabel(-14(1)5) title("Callaway and Sant'Anna (2020)") name(CS, replace)) stub_lag(Tp#) stub_lead(Tm#) together

// 1-4 eventstudyinteract Sun 和 Abraham (2020) 认为还能够使用后处理组作为控制组，允许使用简单的线性回归进行估计 //
sum Ei
// 生成从未受处理组的虚拟变量 
. gen lastcohort = Ei==r(max)
// 生成各期处理组的虚拟变量
 forvalues l = 0/5 {
    gen L`l'event = K==`l'
	}
forvalues l = 1/14 {
      gen F`l'event = K==-`l'
	  }
. drop F1event
ssc install eventstudyinteract
ssc install avar
. eventstudyinteract Y L*event F*event, vce(cluster i) absorb(i t) cohort(Ei) control_cohort(lastcohort)    

event_plot e(b_iw)#e(V_iw), default_look graph_opt(xtitle("Periods since the event") ///
   ytitle("Average causal effect") xlabel(-14(1)5) title("Sun and Abraham (2020)")  ///
 name(SA, replace)) stub_lag(L#event) stub_lead(F#event) together
 
 // 1-5 Cengiz 等 (2019) 认为堆叠 (Stacking) 也是解决 TWFE 估计偏误的替代方法，基本思路是将数据集重建为相对事件时间的平衡面板，然后控制组群效应和时间固定效应，以得到处理效应的加权平均值。//
 
 ssc install stackedev
 
 gen treat_year=.
. replace treat_year=Ei if Ei!=16
. // 生成从未受处理的虚拟变量
. gen no_treat= (Ei==16)
. cap drop F*event L*event
. sum Ei
forvalues l = 0/5 {
  gen L`l'event = K==`l'
  replace L`l'event = 0 if no_treat==1
  }
 forvalues l = 1/14 {
  gen F`l'event = K==-`l'
  replace F`l'event = 0 if no_treat==1
  }
. drop F1event

// 运行 stackedev 命令
. preserve
. stackedev Y F*event L*event, cohort(treat_year) time(t) never_treat(no_treat) unit_fe(i) clust_unit(i)
. restore  

event_plot e(b)#e(V), default_look graph_opt(xtitle("Periods since the event")    ///
   ytitle("Average causal effect") xlabel(-14(1)5) title("Cengiz et al. (2019)") ///
name(CDLZ, replace)) stub_lag(L#event) stub_lead(F#event) together
 
 
 //1-6 TWFE 多维固定效应 //
 reghdfe Y F*event L*event, absorb(i t) vce(cluster i)
 
 event_plot, default_look stub_lag(L#event) stub_lead(F#event) together  ///
 graph_opt(xtitle("Days since the event") ytitle("OLS coefficients") ///
 xlabel(-14(1)5) title("OLS") name(OLS, replace))
 
 // 1-7 两阶段did :在第一阶段识别组群处理效应和时期处理效应的异质性，在第二阶段时再将异质性处理效应剔除//
 ssc install did2s
  did2s Y, first_stage(i.i i.t) second_stage(F*event L*event) treatment(D) cluster(i)

  event_plot, default_look stub_lag(L#event) stub_lead(F#event) together          ///
graph_opt(xtitle("Periods since the event") ytitle("Average causal effect") ///
 xlabel(-14(1)5) title("Gardner (2021)") name(DID2S, replace))
  
  //xtevent //
 ssc install xtevent
 xtevent Y, policyvar(D) panelvar(i) timevar(t) window(4) plot
 
 // eventdd  //
 ssc install eventdd
 ssc install matsort
 eventdd Y i.t,timevar(K) method(fe, cluster(i)) balanced graph_op(ytitle("Y"))  
 
 
 
 
 
 
 
 
 
 
 
 
 


