library(mlr)
library(kernlab)
library(ggplot2)
library(ranger)
library(xgboost)
library(extraTrees)

data(spam)

set.seed(1, kind = "L'Ecuyer-CMRG")
configureMlr(show.info = TRUE)

# makeLearner ------------------------

rf <- makeLearner("classif.ranger", id = "ranger", predict.type = "prob")
rf1000 <- makeLearner("classif.ranger", id = "ranger1000", par.vals = list(num.trees = 1000), 
                      predict.type = "prob")
svm <- makeLearner("classif.ksvm", predict.type = "prob")

# makeClassifTask -----------------------------

library(dplyr)

data(spam)

spam$type = factor(spam$type)
  #ifelse(spam$type=="spam", 1, 0)

mlr_friendly_spam = spam

make_weights <- function(x) {
  x1 <- sum(x == x[1])
  ifelse(x == x[1], 1 - x1/length(x), x1/length(x))
}

spam_task <- makeClassifTask(id = "spam", data = mlr_friendly_spam, target = "type")
spam_task_weight <- makeClassifTask(id = "spam_weight", data = mlr_friendly_spam, 
                                       target = "type", 
                                       weights = make_weights(mlr_friendly_spam[["type"]]))

# makeResampleDesc ------------------------------------------------------

cv5 <- makeResampleDesc(method = "CV", iters = 5)
cv6 <- makeResampleDesc(method = "CV", iters = 6)

# benchmark

bench_res <- benchmark(learners = list(rf, rf1000),
                       tasks = list(spam_task, spam_task_weight), 
                       resamplings = list(cv5, cv6),
                       measures = auc, models = TRUE)

getBMRPerformances(bench_res)
getBMRAggrPerformances(bench_res)
getBMRPredictions(bench_res)
getBMRModels(bench_res)
plotBMRBoxplots(bench_res, pretty.names = FALSE) #+
#  scale_y_continuous(limits = c(0.5, 1))
plotBMRBoxplots(bench_res, pretty.names = FALSE, style = "violin")

# nested cross-validation ----

outer <- makeResampleDesc(method = "CV", iters = 3)
inner <- makeResampleDesc(method = "CV", iters = 5)

ranger_wrapper <- makeTuneWrapper(learner = makeLearner("classif.xgboost", predict.type = "prob"), 
                                  resampling = inner, 
                                  par.set = makeParamSet(makeIntegerParam(id = "nrounds", lower = 10, upper = 200)),
                                  control = makeTuneControlGrid(resolution = 10))

bench <- benchmark(ranger_wrapper, spam_task, resamplings = outer, measures = auc)
rsp <- resample(learner = ranger_wrapper, task = spam_task, resampling = outer, measures = auc, 
                extract = getTuneResult)

res <- getNestedTuneResultsOptPathDf(rsp)
res

getBMRPerformances(bench)
getBMRAggrPerformances(bench)
getBMRPredictions(bench)
getBMRModels(bench)