setwd("~/R") #setwd("C:/Users/mruan/Downloads")
setwd("C:/Users/mruan/Downloads")
install.packages("tidyverse")
install.packages("tidyquant")
install.packages("readxl")
install.packages("factoextra")
install.packages("riskParityPortfolio")
install.packages("PortfolioAnalytics")
install.packages("fPortfolio")
install.packages("rgl")
library(tidyquant)
library(tidyverse)
library(readxl)
library(factoextra)
library(riskParityPortfolio)
library(PortfolioAnalytics)
library(fPortfolio)
library(rgl)

###Read Data###
msci <- read_excel("msci_country_index.xls", skip = 6, col_names = T)
msci <- msci %>% mutate(Date = as.Date(Date))
msci <- msci %>% gather(Index, Value, -Date)
msci <- msci %>% filter(Date >= "2001-01-31")

###Returns###
returns <- msci %>% group_by(Index) %>% 
  tq_transmute(select = Value, mutate_fun = periodReturn,period = 'monthly',type = 'arithmetic')
###Correlations###
correlations <- returns %>% spread(Index, monthly.returns) %>% select(-Date) %>% cor()

###Constructing Portfolios###
#1. MSCI World
msci_world <- read_excel("msci_world_index.xls", skip = 6, col_names = T)
msci_world <- msci_world %>% gather(Index, Value, -Date)
MSCI_World_returns <- msci_world %>% group_by(Index) %>% 
  tq_transmute(select = Value, mutate_fun = periodReturn,period = 'monthly',type = 'arithmetic')

#2. Equal Weight / 1/N
EW_returns <- returns %>% tq_portfolio(assets_col = Index, weights = rep(1/11,11), returns_col = monthly.returns)

#3. Risk parity / ERC
ERC <- riskParityPortfolio(correlations)
ERC_returns <- returns %>% tq_portfolio(assets_col = Index, weights = ERC$w, returns_col = monthly.returns)

#4. Minimum Variance
returns_ts <- as.timeSeries(returns %>% spread(Index, monthly.returns))
MV <- minvariancePortfolio(returns_ts,spec = portfolioSpec(), constraints = "LongOnly")
MV_returns <- returns %>% tq_portfolio(assets_col = Index, weights = getWeights(MV), returns_col = monthly.returns) 

###PCA Analysis###
#PC Variance Explained i.e. Importance of Components
pca <- returns %>% spread(Index, monthly.returns) %>% select(-Date) %>% as.matrix() %>% prcomp(scale. = T, center = T)
pca %>% summary()
pca %>% fviz_eig()
#PC Eigenvectors i.e. Values by which our original variables are multiplied by to calculate the PC score
pca$rotation
eigenvectors <- returns %>% spread(Index, monthly.returns) %>% select(-Date) %>% as.matrix() %>%
  cor() %>% eigen()
eigenvectors$vectors
#Eigenvalues
eigenvectors$values
pca$sdev^2
#Interpreting PCs
biplot(pca, scale = 0)
pca %>% fviz_pca_var(repel = T)
#We see that PCA 1 tends to be explained equally by all countries,hence the market risk factor
#PCA 2 is associated with high values of developed, western countries vs. Asian, perhaps EM countries

#Determing number of PCs to keep (significance)
#a. Scree graph - Slope significantly flatens at 4 PCs
pca %>% fviz_eig()
#b Cumulative variance cutoff of 70% - 90% - between 2 and 5 PCs
pca %>% summary()
#c Kaiser Rule - keep those eigenvalues with 1, or minimum 0.7 - keep 2 PCs
eigenvectors$values
#Conclusion - good middle ground is 3 PCs

#5. Diversified Risk Parity
PP1_returns <- returns %>% tq_portfolio(assets_col = Index, weights = pca$rotation[,1], returns_col = monthly.returns)
PP2_returns <- returns %>% tq_portfolio(assets_col = Index, weights = pca$rotation[,2], returns_col = monthly.returns)
PP3_returns <- returns %>% tq_portfolio(assets_col = Index, weights = pca$rotation[,3], returns_col = monthly.returns)
PC_portfolios <- left_join(PP1_returns, PP2_returns, by = "Date")
PC_portfolios <- left_join(PC_portfolios, PP3_returns, by = "Date")
DRP <- riskParityPortfolio(PC_portfolios %>% select(-Date) %>% cor())
DRP_returns <- PC_portfolios %>% gather(PP, Returns, -Date) %>% 
  tq_portfolio(assets_col = PP, weights = DRP$w, returns_col = Returns)

###Compare performance###
#a. Trajectory
portfolios <- left_join(EW_returns, ERC_returns,by = "Date")
portfolios <- left_join(portfolios, MV_returns,by = "Date")
portfolios <- left_join(portfolios, MSCI_World_returns[,2:3]%>% mutate(Date = as.Date(Date)),by = "Date")
portfolios <- left_join(portfolios, DRP_returns,by = "Date")
portfolios_xts<- as.xts(portfolios %>% remove_rownames %>% column_to_rownames(var="Date"))
colnames(portfolios_xts) <- c("1/N", "ERC", "MV", "MSCI World", "DRP")
charts.PerformanceSummary(portfolios_xts, Rf = 0, main = NULL, geometric = TRUE,methods = "none", width = 0, 
                          event.labels = TRUE, ylog = FALSE,wealth.index = TRUE, gap = 12, begin = c("first", "axis"),
                          legend.loc = "topleft", p = 0.95)

#b. Descriptive Statistics e.g. Sharpe Ratio
MSCI_World_returns %>% tq_portfolio(assets_col = Index, weights = c(1), returns_col = monthly.returns) %>% 
  tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100
EW_returns %>% tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100
ERC_returns %>% tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100
MV_returns %>% tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100
DRP_returns %>% tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100
setwd("~/R") #setwd("C:/Users/mruan/Downloads")
setwd("C:/Users/mruan/Downloads")
install.packages("tidyverse")
install.packages("tidyquant")
install.packages("readxl")
install.packages("factoextra")
install.packages("riskParityPortfolio")
install.packages("PortfolioAnalytics")
install.packages("fPortfolio")
install.packages("rgl")
library(tidyquant)
library(tidyverse)
library(readxl)
library(factoextra)
library(riskParityPortfolio)
library(PortfolioAnalytics)
library(fPortfolio)
library(rgl)

### MSCI World Constituents / Country Indices ###
msci <- read_excel("historyIndex.xls", skip = 6, col_names = T)
msci <- msci %>% mutate(Date = as.Date(Date))
msci <- msci %>% gather(Index, Value, -Date)
msci <- msci %>% dplyr::filter(Date >= "2001-01-31")
returns <- msci %>% group_by(Index) %>% 
  tq_transmute(select = Value, mutate_fun = periodReturn,period = 'monthly',type = 'arithmetic')


#Convert full sample to 1st 5 years
backtestperiod <- (returns %>% spread(Index, monthly.returns))[1:60,]
backtestperiod <- (returns %>% spread(Index, monthly.returns))[2:61,]

#4. Minimum Variance
returns_ts <- as.timeSeries(returns %>% spread(Index, monthly.returns))
rollingWindows(returns_ts, period = "12m", by = "1m")
MV <- minvariancePortfolio(returns_ts,spec = portfolioSpec(), constraints = "LongOnly")
getWeights(MV)
MV_returns <- returns %>% tq_portfolio(assets_col = Index, weights = getWeights(MV), returns_col = monthly.returns) 
MV_returns[61,]

#Rolling Window Minimum Variance
bt_mv_returns <- tibble()
for (btp in 1:160){
  i <- btp + 59
  backtestperiod <- (returns %>% spread(Index, monthly.returns))[btp:i,]
  returns_ts <- as.timeSeries(backtestperiod)
  MV <- minvariancePortfolio(returns_ts,spec = portfolioSpec(), constraints = "LongOnly")
  MV_returns <- returns %>% tq_portfolio(assets_col = Index, weights = getWeights(MV), returns_col = monthly.returns)
  bt_mv_returns <- bind_rows(bt_mv_returns, MV_returns[i + 1,])
}
bt_mv_returns %>% tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100

#Rolling Window ERC
bt_ERC_returns <- tibble()
for (btp in 1:160){
  i <- btp + 59
  backtestperiod <- (returns %>% spread(Index, monthly.returns))[btp:i,]
  ERC <- riskParityPortfolio(backtestperiod %>% select(-Date) %>% cor())
  ERC_returns <- returns %>% tq_portfolio(assets_col = Index, weights = ERC$w, returns_col = monthly.returns)
  bt_ERC_returns <- bind_rows(bt_ERC_returns, ERC_returns[i + 1,])
}
bt_ERC_returns %>% tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100

#5. Diversified Risk Parity
bt_DRP_returns <- tibble()
for (btp in 1:160){
  i <- btp + 59
  backtestperiod <- (returns %>% spread(Index, monthly.returns))[btp:i,]
  pca <- backtestperiod %>% select(-Date) %>% as.matrix() %>% prcomp(scale. = T, center = T)
  PP1_returns <- returns %>% tq_portfolio(assets_col = Index, weights = pca$rotation[,1], returns_col = monthly.returns)
  PP2_returns <- returns %>% tq_portfolio(assets_col = Index, weights = pca$rotation[,2], returns_col = monthly.returns)
  PP3_returns <- returns %>% tq_portfolio(assets_col = Index, weights = pca$rotation[,3], returns_col = monthly.returns)
  PP4_returns <- returns %>% tq_portfolio(assets_col = Index, weights = pca$rotation[,4], returns_col = monthly.returns)
  PC_portfolios <- left_join(PP1_returns, PP2_returns, by = "Date")
  PC_portfolios <- left_join(PC_portfolios, PP3_returns, by = "Date")
  PC_portfolios <- left_join(PC_portfolios, PP4_returns, by = "Date")
  DRP <- riskParityPortfolio(PC_portfolios[btp:i,] %>% select(-Date) %>% cor())
  DRP_returns <- PC_portfolios %>% gather(PP, Returns, -Date) %>% tq_portfolio(assets_col = PP, weights = DRP$w, returns_col = Returns)
  bt_DRP_returns <- bind_rows(bt_DRP_returns, DRP_returns[i + 1,])
}
bt_DRP_returns %>% tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100

#Rolling Window EW
bt_EW_returns <- tibble()
for (btp in 1:160){
  i <- btp + 59
  EW_returns <- returns %>% tq_portfolio(assets_col = Index, weights = rep(1/23,23), returns_col = monthly.returns)
  bt_EW_returns <- bind_rows(bt_EW_returns, EW_returns[i + 1,])
}
bt_EW_returns %>% tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100

#Rolling Window MSCI World
bt_world_returns <- tibble()
for (btp in 1:160){
  i <- btp + 59
  bt_world_returns <- bind_rows(bt_world_returns, MSCI_World_returns[i + 1,])
}
bt_world_returns %>% tq_portfolio(assets_col = Index, weights = c(1), returns_col = monthly.returns) %>% 
  tq_performance(Ra = portfolio.returns, performance_fun = table.AnnualizedReturns) * 100
