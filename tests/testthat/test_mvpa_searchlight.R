library(neuroim)



gen_dataset <- function(D, nobs, nlevels, spacing=c(1,1,1), folds=5) {
  mat <- array(rnorm(prod(D)*nobs), c(D,nobs))
  bspace <- BrainSpace(c(D,nobs), spacing)
  bvec <- BrainVector(mat, bspace)
  mask <- as.logical(BrainVolume(array(rep(1, prod(D)), D), BrainSpace(D, spacing)))
  Y <- sample(factor(rep(letters[1:nlevels], length.out=nobs)))
  blockVar <- rep(1:folds, length.out=nobs)
  MVPADataset(trainVec=bvec, Y=Y, mask=mask, blockVar=blockVar, testVec=NULL, testY=NULL)
}

test_that("standard mvpa_searchlight runs without error", {
  
  dataset <- gen_dataset(c(5,5,1), 100, 2)
  crossVal <- BlockedCrossValidation(dataset$blockVar)
  res <- mvpa_searchlight(dataset, crossVal, radius=3, method="standard")
  
})

test_that("randomized mvpa_searchlight runs without error", {
  
  dataset <- gen_dataset(c(5,5,1), 100, 2)
  crossVal <- BlockedCrossValidation(dataset$blockVar)
  res <- mvpa_searchlight(dataset, crossVal, radius=3, method="randomized")
  
})

test_that("standard mvpa_searchlight and tune_grid runs without error", {
  
  dataset <- gen_dataset(c(2,2,1), 50, 2, folds=3)
  crossVal <- BlockedCrossValidation(dataset$blockVar)
  dataset$model <- loadModel("sda")
  dataset$tuneGrid <- expand.grid(lambda=c(.1,.8), diagonal=c(TRUE))
  res <- mvpa_searchlight(dataset, crossVal, radius=3, method="standard")
  
})

test_that("standard mvpa_searchlight and tune_grid with two-fold cross-validation runs without error", {
  
  dataset <- gen_dataset(c(2,2,1), 50, 2, folds=2)
  crossVal <- BlockedCrossValidation(dataset$blockVar)
  dataset$model <- loadModel("sda")
  dataset$tuneGrid <- expand.grid(lambda=c(.1,.8), diagonal=c(TRUE))
  res <- mvpa_searchlight(dataset, crossVal, radius=3, method="standard")
  
})

test_that("randomized mvpa_searchlight and tune_grid runs without error", {
  
  dataset <- gen_dataset(c(2,2,1), 100, 2, folds=3)
  crossVal <- BlockedCrossValidation(dataset$blockVar)
  dataset$model <- loadModel("sda")
  dataset$tuneGrid <- expand.grid(lambda=c(.1,.8), diagonal=c(TRUE))
  res <- mvpa_searchlight(dataset, crossVal, radius=3, niter=2,method="randomized")
  
})



