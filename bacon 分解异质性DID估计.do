***** Bacon 分解


ssc install bacondecomp,replace  //安装命令
use http://pped.org/bacon_example.dta,clear  //打开数据

xtreg asmrs post pcinc asmrh cases i.year, fe robust

bacondecomp asmrs post pcinc asmrh cases, stub(Bacon_) robust

bacomdecomp asmrs post,ddetail 












*******异质性DID 估计量

clear all
timer clear

* 设定随机数种子, 设置 4500 个样本观测值
. set seed 10
. global T = 15
. global I = 300
. set obs `=$I*$T'

* 生成 id 与时间
. gen i = int((_n-1)/$T )+1
. gen t = mod((_n-1),$T )+1
. tsset i t

* 随机生成每个 i d首次接受处理的时间标志, Ei 的取值在 10 和 16 之间
. gen Ei = ceil(runiform()*7)+$T -6 if t==1
. bys i (t): replace Ei = Ei[1]

 * 生成处理变量, K 为相对处理时间, D 为处理时间哑变量
. gen K = t-Ei
. gen D = K>=0 & Ei!=.

* 生成时间上的异质性处理效应
. gen tau = cond(D==1, (t-12.5), 0)

* 生成误差项
. gen eps = rnormal()

* 生成结果变量Y
. gen Y = i + 3*t + tau*D + eps

* Borusyak 等 (2021) 提供了一种基于插补的反事实方法解决 TWFE 的估计偏误问题。基于 TWFE，
* 通过估计组群固定效应、时间固定效应和处理组-控制组固定效应，可以得到更准确的估计量
did_imputation Y i t Ei, allhorizons pretrends(5)

event_plot, default_look graph_opt(xtitle("Periods since the event") ytitle("Average causal effect") ///
title("Borusyak et al. (2021) imputaion estimator") xlabel(-5(1)5) name(BJS, replace)) together

*3.2 did_multiplegt
*De Chaisemartin 和 D‘Haultfoeuille (2020) 提出通过加权计算两种处理效应的值得到平均处理效应的无偏估计，这两种处理效应为：

 *t-1期未受处理而 t 期受处理的组与两期都未处理的组的平均处理效应；
 *t-1期受处理而 t 期未受处理的组与两期都受处理的组的平均处理效应。
*该方法的前提条件是处理效应不具有动态性 (即处理效应与过去的处理状态无关)，

did_multiplegt Y i t D, robust_dynamic dynamic(5) placebo(5) longdiff_placebo breps(100) cluster(i)

event_plot e(estimates)#e(variances), default_look graph_opt(xtitle("Periods since the event") ///
>     ytitle("Average causal effect") title("de Chaisemartin and D'Haultfoeuille (2020)")        ///
>     xlabel(-5(1)5) name(dCdH, replace)) stub_lag(Effect_#) stub_lead(Placebo_#) together


*3.3 csdid
*Callaway 和 SantAnna (2021) 将  t期以前从未受处理的组作为控制组进行估计，代码如下：
* 生成日期变量，从未受处理的组取值为 0
. gen gvar = cond(Ei>15, 0, Ei)
. csdid Y, ivar(i) time(t) gvar(gvar) agg(event)

event_plot e(b)#e(V), default_look graph_opt(xtitle("Periods since the event")             ///
>     ytitle("Average causal effect") xlabel(-14(1)5) title("Callaway and Sant'Anna (2020)") ///
>     name(CS, replace)) stub_lag(T+#) stub_lead(T-#) together


3.4 eventstudyinteract
Sun 和 Abraham (2020) 认为还能够使用后处理组作为控制组，允许使用简单的线性回归进行估计，代码如下：

sum Ei
*生成从未受处理组的虚拟变量
. gen lastcohort = Ei==r(max)
 * 生成各期处理组的虚拟变量
. forvalues l = 0/5 {
  2.     gen L`l'event = K==`l'
  3. }
. forvalues l = 1/14 {
  2.     gen F`l'event = K==-`l'
  3. }
. drop F1event
. eventstudyinteract Y L*event F*event, vce(cluster i) absorb(i t) cohort(Ei) control_cohort(lastcohort)    


*如果出现报错 command avar is unrecognized，则输入 ssc install avar，安装后再次运行命令。

event_plot e(b_iw)#e(V_iw), default_look graph_opt(xtitle("Periods since the event") ///
>     ytitle("Average causal effect") xlabel(-14(1)5) title("Sun and Abraham (2020)")  ///
>     name(SA, replace)) stub_lag(L#event) stub_lead(F#event) together


*3.5 did2s
* Gardner (2021) 提出的两阶段双重差分的基本原理：在第一阶段识别组群处理效应和时期处理效应的异质性，在第二阶段时再将异质性处理效应剔除，
did2s Y, first_stage(i.i i.t) second_stage(F*event L*event) treatment(D) cluster(i)

event_plot, default_look stub_lag(L#event) stub_lead(F#event) together          ///
>     graph_opt(xtitle("Periods since the event") ytitle("Average causal effect") ///
>     xlabel(-14(1)5) title("Gardner (2021)") name(DID2S, replace))

*3.6 stackedev
*与计算加权 ATT 的方法相比，Cengiz 等 (2019) 认为堆叠 (Stacking) 也是解决 TWFE 估计偏误的替代方法，基本思路是将数据集重建为相对事件时间的平衡面板，然后控制组群效应和时间固定效应，以得到处理效应的加权平均值。
 gen treat_year=.
. replace treat_year=Ei if Ei!=16
. * 生成从未受处理的虚拟变量
. gen no_treat= (Ei==16)
. cap drop F*event L*event
. sum Ei
. forvalues l = 0/5 {
  2.     gen L`l'event = K==`l'
  3.     replace L`l'event = 0 if no_treat==1
  4. }
. forvalues l = 1/14 {
  2.     gen F`l'event = K==-`l'
  3.     replace F`l'event = 0 if no_treat==1
  4. }
. drop F1event

. * 运行 stackedev 命令
. preserve
. stackedev Y F*event L*event, cohort(treat_year) time(t) never_treat(no_treat) unit_fe(i) clust_unit(i)
. restore  


event_plot e(b)#e(V), default_look graph_opt(xtitle("Periods since the event")    ///
>     ytitle("Average causal effect") xlabel(-14(1)5) title("Cengiz et al. (2019)") ///
>     name(CDLZ, replace)) stub_lag(L#event) stub_lead(F#event) together

*3.7 TWFE OLS
*多维固定效应 OLS 代码：
reghdfe Y F*event L*event, absorb(i t) vce(cluster i)


event_plot, default_look stub_lag(L#event) stub_lead(F#event) together  ///
>     graph_opt(xtitle("Days since the event") ytitle("OLS coefficients") ///
>     xlabel(-14(1)5) title("OLS") name(OLS, replace))

*3.8 xtevent
Freyaldenhoven 等 (2019) 提出处理面板事件研究的估计方法，代码如下：

xtevent Y, policyvar(D) panelvar(i) timevar(t) window(4) plot    


*3.9 eventdd
*eventdd 是 Damian Clarke 和 Kathya Tapia (2020) 共同开发的事件研究法代码，

eventdd Y i.t,timevar(K) method(fe, cluster(i)) balanced graph_op(ytitle("Y"))    

此外，还有 drdid、flexpaneldid、staggered、jwdid 等命令。在实际应用过程中，为了解决 TWFE 估计偏误的问题，不妨将上述异质性稳健估计量都使用一遍，若能够通过大部分的估计量检验，那么结果就是可靠的。






