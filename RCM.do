
**计量经济学Econometrics circle************************************************************************//

*示例 1：估计 1997 年第三季度香港与中国内地政治一体化的影响（Hsiao 等，2012）

. ssc install rcm, all replace

. use growth, clear 

. xtset region time 

*显示香港的编号及政策处理时期的编号

. label list 

. display tq(1997q3) 

. display tq(2003q4) 

*使用指定的控制单位和指定的后处理时期期，复现出Hsiao 等人 (2012) 中的结果

. rcm gdp, trunit(9) trperiod(150) ctrlunit(4 10 12 13 14 19 20 22 23 25) postperiod(150/175) 

*使用带有LOOCV 和所有控制单元的后套索 OLS，并创建一个 Stata 框架“growth_wide”，以广泛的形式存储生成的变量，包括反事实预测、处理效应和安慰剂检验的结果

. rcm gdp, trunit(9) trperiod(150) postperiod(150/175) method(lasso) criterion(cv) frame(growth_wide) 

*更改为生成的 Stata 框架“growth_wide”

. frame change growth_wide 

*改回默认的Stata框架

. frame change default 

*使用donor pool中的所有虚假处理单元实施安慰剂检验

. rcm gdp, trunit(9) trperiod(150) postperiod(150/175) method(lasso) criterion(cv) placebo(unit) 

---

*示例 2：估计 2004 年第一季度香港与 中国大陆经济一体化的影响（Hsiao 等，2012）

. use growth, clear 

. xtset region time 

*显示香港单元编号及政策处理期

. label list 

. display tq(2004q1) 

*使用所有控制单元复现 Hsiao 等人 (2012) 中的结果

. rcm gdp, trunit(9) trperiod(176) method(best) 

*使用带有 LOOCV 的 post-lasso OLS，并创建一个 Stata 框架“growth_wide”，以宽格式存储生成的变量

. rcm gdp, trunit(9) trperiod(176) method(lasso) criterion(cv) frame(growth_wide) 

*使用donor pool中的所有虚假处理单元实施安慰剂检验，虚假处理时间 2002q1

. display tq(2002q1) . rcm gdp, trunit(9) trperiod(176) method(lasso) criterion(cv) placebo(unit period(168)) 


*示例 3：估计 1990 年德国统一的影响 (Abadie et al ., 2015)

. use repgermany.dta, clear 

. xtset country year 

*显示西德的单元号

. label list 

*使用无协变量的 10 倍交叉验证后套索 OLS

. rcm gdp, tru(17) trp(1990) me(lasso) cr(cv) fold(10)

*使用三个协变量作为附加的预测变量

. rcm gdp infrate trade industry, tru(17) trp(1990) me(lasso) cr(cv) fold(10) 

Fill in missing values by sample means for each units, and implement placebo tests using the fake treatment units with pre-treatment MSPE 10 times smaller than or equal to that of the treated unit 

*对每个单元按样本均值填充缺失值，并使用处理前MSPE小于或等于处理单元10倍的虚假处理单元进行安慰剂检验

. rcm gdp infrate trade industry, tru(17) trp(1990) me(lasso) cr(cv) fold(10) fill(mean) placebo(unit cut(10)) 

*对每个单元按样本均值填充缺失值，并实施虚假处理时间的安慰剂检验

. rcm gdp infrate trade industry, tru(17) trp(1990) me(lasso) cr(cv) fold(10) fill(mean) placebo(period(1980)) 

*通过线性插值对每个单元填充缺失值，并创建一个Stata框架“WestGermany_wide”，以宽格式存储生成的变量

. rcm gdp infrate trade industry, tru(17) trp(1990) me(lasso) cr(cv) fold(10) fill(linear) frame(WestGermany_wide)