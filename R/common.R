#' @include mvpa_model.R
NULL
 

initializeROIGrouping <- function(config) {
  if (!is.null(config$roi_grouping)) {
    roilist <- lapply(1:length(config$roi_grouping), function(i) {
      grp <- config$roi_grouping[[i]]
      idx <- which(config$ROIVolume %in% grp)
      vol <- makeVolume(refvol=config$ROIVolume)
      vol[idx] <- i
      vol
    })
    
    if (is.null(names(config$roi_grouping))) {
      names(roilist) <- paste0("roi_group_", seq_along(config$roi_grouping))
    } else {
      names(roilist) <- names(config$roi_grouping)
    }
    config$ROIVolume <- roilist
  } else {
    config$ROIVolume <- list(config$ROIVolume)
  }
}


initializeROISubset <- function(config) {
  if (!is.null(config$roi_subset)) {
    form <- try(eval(parse(text=config$roi_subset)))
    if (inherits(form, "try-error")) {
      flog.error("could not parse roi_subset parameter: %s", config$roi_subset)
      stop()
    }
    
    if (class(form) != "formula") {
      flog.error("roi_subset argument must be an expression that starts with a ~ character")
      stop()
    }
    
    res <- as.logical(eval(form[[2]], list(x=config$ROIVolume)))
    
    config$ROIVolume[!res] <- 0
    flog.info("roi_subset contains %s voxels", sum(config$ROIVolume > 0))
  }
}


#' @export
initMVPARegional <- function(configFile, args=list(), verbose=FALSE) {
  if (!verbose) {
    flog.threshold(ERROR)
  } else {
    flog.threshold(DEBUG)
  }
  
  config <- initializeConfiguration(list(config=configFile))
  config <- initializeStandardParameters(config, args, "mvpa_regional")

  setArg("savePredictors", config, args, FALSE)
  
  config <- initializeTuneGrid(args, config)
  configParams <- as.list(config)
  config <- initializeDesign(config)
  
  rowIndices <- which(config$train_subset)
  config$ROIVolume <- loadMask(config)
  
  initializeROISubset(config)
  initializeROIGrouping(config)
  
  parcellationVolume <- if (!is.null(config$parcellation)) {
    loadVolume(config$parcellation)
  }
  
  config$maskVolume <- as(Reduce("+", lapply(config$ROIVolume, function(roivol) as(roivol, "LogicalBrainVolume"))), "LogicalBrainVolume")
  config <- initializeData(config)
  
  flog.info("number of training trials: %s", length(rowIndices))
  
  flog.info("max trial index: %s", max(rowIndices))
  
  flog.info("loading training data: %s", config$train_data)
  
  flog.info("mask contains %s voxels", sum(config$maskVolume))
  
  for (i in seq_along(config$ROIVolume)) {
    rvol <- config$ROIVolume[[i]]
    
    flog.info("Region mask contains: %s ROIs", length(unique(rvol[rvol > 0])))
    flog.info(paste("ROIs are for group ", i, "are:"), rvol, capture=TRUE)
    
  }
  
  flog.info("Running regional MVPA with parameters:", configParams, capture=TRUE)
  
  flog.info("With %s roi groups", length(config$ROIVolume))
  
  if (length(config$labels) != dim(config$train_datavec)[4]) {
    flog.error("Number of volumes: %s must equal number of labels: %s", dim(config$train_datavec)[4], length(config$labels))
    stop()
  }
  
  featureSelector <- if (!is.null(config$feature_selector)) {
    FeatureSelector(config$feature_selector$method, config$feature_selector$cutoff_type, as.numeric(config$feature_selector$cutoff_value))
  }
  
  flog.info("feature selector: ", featureSelector, capture=TRUE)
  
  flog.info("bootstrap replications: ", config$bootstrap_replications, capture=TRUE)
  
  dataset <- MVPADataset(config$train_datavec, config$labels, config$maskVolume, config$block, config$test_datavec, 
                         config$testLabels, modelName=config$model, tuneGrid=config$tune_grid,
                         tuneLength=config$tune_length, testSplitVar=config$testSplitVar, testSplits=config$testSplits, 
                         trainDesign=config$train_design,
                         testDesign=config$test_design)
  
  for (varname in c("test_subset", "train_subset", "roi_subset", "split_by")) {
    if (!is.null(configParams[[varname]]) && is(configParams[[varname]], "formula")) {
      configParams[[varname]] <- Reduce(paste, deparse(configParams[[varname]]))
    }
  }
  
  for (lib in dataset$model$library) {
    library(lib, character.only = TRUE)
  }
  
  list(dataset=dataset, config=config)
  
}


#' @export
initMVPASearchlight <- function(configFile, args=list(), verbose=FALSE) {
  if (!verbose) {
    flog.threshold(ERROR)
  } else {
    flog.threshold(DEBUG)
  }
  
  
  config <- initializeConfiguration(list(config=configFile))
  config <- initializeStandardParameters(config, args, "mvpa_searchlight")
  
  setArg("niter", config, args, 16)
  setArg("radius", config, args, 8)
  setArg("type", config, args, "randomized")
  
  config <- initializeTuneGrid(args, config)
  configParams <- as.list(config)
  config <- initializeDesign(config)
  
  config$maskVolume <- as(loadMask(config), "LogicalBrainVolume")
  
  
  rowIndices <- which(config$train_subset)
  config$ROIVolume <- loadMask(config)
  
  rowIndices <- which(config$train_subset)
  flog.info("number of trials: %s", length(rowIndices))
  flog.info("max trial index: %s", max(rowIndices))
  flog.info("loading training data: %s", config$train_data)
  flog.info("mask contains %s voxels", sum(config$maskVolume))
  
  config <- initializeData(config)
  
  flog.info("Running searchlight with parameters:", configParams, capture=TRUE)
  
  
  dataset <- MVPADataset(config$train_datavec, 
                         config$labels, 
                         config$maskVolume, 
                         config$block, 
                         config$test_datavec, 
                         config$testLabels, 
                         modelName=config$model, 
                         tuneGrid=config$tune_grid,
                         tuneLength=config$tune_length, 
                         testSplitVar=config$testSplitVar, 
                         testSplits=config$testSplits,
                         trainDesign=config$train_design,
                         testDesign=config$test_design)
  
  for (lib in dataset$model$library) {
    library(lib, character.only = TRUE)
  }
  
  list(dataset=dataset, config=config)
}



#' @export
#' @import stringr
initializeConfiguration <- function(args) {
  
  if (!is.null(args$config)) {
    if (! file.exists(args$config)) {
      flog.error("cannot find configuration file: %s", args$config)
      stop()
    } else if (str_detect(args$config, "\\.yaml$")) {
      confyaml <- qread(args$config)
      config <- as.environment(confyaml)
    } else if (str_detect(args$config, "\\.[rR]")) {
      config <- new.env()
      source(args$config, config)
    }
  }
  
  config

  
}

#' @export
initializeStandardParameters <- function(config, args, analysisType) {
  #setArg("radius", config, args, 8)
  setArg("train_design", config, args, "mvpa_design.txt")
  setArg("test_design", config, args, NULL)
  setArg("train_data", config, args, "mvpa_design.txt")
  setArg("test_data", config, args, NULL)
  #setArg("type", config, args, "randomized")
  setArg("model", config, args, "corsim")
  setArg("pthreads", config, args, 1)
  setArg("label_column", config, args, "labels")
  setArg("skipIfFolderExists", config, args, FALSE)
  setArg("customPerformance", config, args, NULL)
  setArg("output", config, args, paste0(analysisType, "_", config$labelColumn))
  setArg("block_column", config, args, "block")
  setArg("normalize", config, args, FALSE)
  setArg("autobalance", config, args, FALSE)
  setArg("tune_length", config, args, 1)
  #setDefault("autobalance", config, FALSE)
  setArg("tune_grid", config, args, NULL)
  #setDefault("method_params", config, list())
  #setArg("niter", config, args, 4)
  setArg("mask", config, args, NULL)
  setArg("output_class_metrics", config, args, TRUE)
  setArg("ensemble_predictor", config, args, FALSE)
  setArg("bootstrap_replications", config, args, 0)
  setArg("test_label_column", config, args, config$label_column)
  
  config
}

#' @export
normalizeSamples <- function(bvec, mask) {
  norm_datavec <- do.call(cbind, eachVolume(bvec, function(x) scale(x)[,1], mask=mask))
  SparseBrainVector(norm_datavec, space(bvec), mask=mask)  
}

#' @export
initializeData <- function(config) {
  
  if (!is.null(config$train_subset)) {
    indices=which(config$train_subset)
    flog.info("length of training subset %s", length(indices))
    config$train_datavec <- loadBrainData(config, "train_data", indices=indices)    
  } else {
    config$train_datavec <- loadBrainData(config, "train_data")  
  }
  
  if (!is.null(config$test_data)) {
    flog.info("loading test data: %s", config$test_data)
    indices=which(config$test_subset)
    flog.info("length of test subset %s", length(indices))
    
    if (!is.null(config$test_subset)) {
      config$test_datavec <- loadBrainData(config, "test_data", indices=indices)
    } else {
      config$test_datavec <- loadBrainData(config, "test_data")
    }
  }
  
  if (config$normalize) {
    flog.info("Normalizing: centering and scaling each volume of training data")
    config$train_datavec <- normalizeSamples(config$train_datavec, config$maskVolume)
    
    if (!is.null(config$test_data)) {
      flog.info("Normalizing: centering and scaling each volume of test data")
      config$test_datavec <- normalizeSamples(config$test_datavec, config$maskVolume)
    }
  }
  
  config

  
}

#' @export
initializeDesign <- function(config) {
  if (is.character(config$train_subset)) {
    config$train_subset <- eval(parse(text=config$train_subset))
  }
  
  if (is.character(config$test_subset)) {
    config$test_subset <- eval(parse(text=config$test_subset))
  }
  
  ## full design
  config$full_train_design <- read.table(config$train_design, header=TRUE, comment.char=";")
  ## subset of training samples
  config$train_subset <- loadSubset(config$full_train_design, config$train_subset)
  ## training design
  config$train_design <- config$full_train_design[config$train_subset,]
  
  ## training labels
  config$labels <- loadLabels(config$train_design, config)  
  ## block variables for cross-validation
  config$block <- loadBlockColumn(config, config$train_design)
  
  flog.info(paste("training subset contains", nrow(config$train_design), "of", nrow(config$full_design), "rows."))
  
  if (!is.null(config$test_design) && is.null(config$test_data)) {
    flog.error("test_design %s is supplied with no test_data")
    stop()
  }
  
  if (!is.null(config$test_subset) && is.null(config$test_design) && is.null(config$test_data)) {
    flog.info("test subset is taken from training design table")
    config$test_subset <- loadSubset(config$full_train_design, config$test_subset)
    
    config$test_design <- config$full_train_design[config$test_subset,]
    config$full_test_design <- config$test_design
    config$testLabels <- loadLabels(config$test_design, config)   
  }
  
  if (!is.null(config$test_design)) {
    flog.info("test design %s is specified", config$test_design)
    config$full_test_design <- read.table(config$test_design, header=TRUE, comment.char=";")
    config$test_subset <- loadSubset(config$full_test_design, config$test_subset)
    config$test_design <- config$full_test_design[config$test_subset,]
    config$testLabels <- loadTestLabels(config$test_design, config)     
    flog.info(paste("test subset contains", nrow(config$test_design), "of", nrow(config$full_test_design), "rows.")) 
    flog.info(paste("first 10 test labels: ", head(config$testLabels, 10), capture=TRUE))
    
  } else {
    flog.info("testing is cross-validation")
    config$testLabels <- config$labels
  }
  
  if (!is.null(config$split_by)) {
    
    form <- eval(parse(text=config$split_by))
    flog.info("will split performance metrics by %s", as.character(form)[[2]])
    vars <- all.vars(form[[2]])
    des <- if (!is.null(config$test_design)) config$test_design else config$train_design
    config$testSplitVar <- do.call("interaction", lapply(vars, function(vname) as.factor(des[[vname]])))
    flog.info("splitting levels are: %s", paste(levels(config$testSplitVar), collapse=", "))
    minSplits <- min(table(config$testSplitVar))
    if (minSplits < 3) {
      flog.error("splitting condition results in fewer than 3 observations in at least one set", table(config$splittingVar), capture=TRUE)
      stop(paste("invalid split formula", config$split_by))
    }
    
    config$testSplits <- split(1:length(config$testLabels), config$testSplitVar)
    
  }
    
  
  config
  
}

#initializeFeatureSelection <- function(args, grid) {
#  if (!is.null(args$feature_selection) && !args$feature_selection == "NULL") {
#    
#}

#' @export
initializeTuneGrid <- function(args, config) {
  if (!is.null(args$tune_grid) && !args$tune_grid == "NULL") {
    params <- try(expand.grid(eval(parse(text=args$tune_grid))))
    if (inherits(params, "try-error")) {
      stop("could not parse tune_grid expresson: ", args$tune_grid)
    }
    flog.info("tuning grid is", params, capture=TRUE)
    config$tune_grid <- params
  } else if (!is.null(config$tune_grid) && !is.data.frame(config$tune_grid)) {
    params <- try(lapply(config$tune_grid, function(x) eval(parse(text=x))))
    if (inherits(params, "try-error")) {
      stop("could not parse tune_grid expresson: ", config$tune_grid)
    }
    
    config$tune_grid <- expand.grid(params)
    flog.info("tuning grid is", params, capture=TRUE)
  }
  
  config
}


#' @export
setDefault <- function(name, config, default) {
  if (is.null(config[[name]])) {
    config[[name]]<- default
  }
}

#' @export
setArg <- function(name, config, args, default) {
  if (is.null(config[[name]]) && is.null(args[[name]])) {
    config[[name]] <- default
  } else if (!is.null(args[[name]])) {
    config[[name]] <- args[[name]]
  } else if (is.null(config[[name]])) {
    config[[name]] <- default
  }    
}

#' @export
makeOutputDir <- function(dirname) {
  if (!file.exists(dirname)) {
    system(paste("mkdir", dirname))
    dirname
  } else {
    dirname <- paste(dirname, "+", sep="")
    Recall(dirname)
  }
}

#' @export
abort <- function(config, msg) {
  stop(msg)
}

#' @export
logit <- function(config, msg) {
  #writeLines(msg, config$logFile)
}

#' @export
loadModel <- function(name, config=NULL) {
  ##registry <- get("MVPAModels", .GlobalEnv)
  registry <- rMVPA:::MVPAModels
  
  ## total hack, for now.
  if (name == "searchlight_ensemble" || name == "search_ensemble") {
    if (!is.null(config$learners)) {
      EnsembleSearchlightModel(config$learners)
    } else {
      EnsembleSearchlightModel()
    }
  #} else if (name == "roi_ensemble") {
  #  stop()
  } else if (name == "pattern_sim" || name == "pattern_similarity") {
    SimilarityModel()
  } else if (!is.null(registry[[name]])) {
    ClassificationModel(registry[[name]])       
  } else if (length(caret::getModelInfo(name)) > 0) {
    ClassificationModel(caret::getModelInfo(name)[[name]])    
  } else {
    abort(paste("unrecognized model: ", name))
  }
}

#' @export
loadMask <- function(config) {
  if (file.exists(config$mask)) {
    mask <- loadVolume(config$mask)
  } else {
    stop(paste("cannot find mask file named: ", config$mask))
  }
  
  mask
}

#' @export
loadDesign <- function(config, name) {
  if (!file.exists(config[[name]])) {
    stop(paste("cannot find table named", config$table))
  } else {
    read.table(config[[name]], header=TRUE, comment.char=";")
  }
}

#' @export
loadLabels <- function(full_design, config) {
  if (is.null(full_design[[config$label_column]])) {
    stop(paste("Error: labelColumn", config$label_column, "not found"))
  } else {
    labels <- factor(full_design[[config$label_column]])
  }
  labels
}

loadTestLabels <- function(full_design, config) {
  if (is.null(full_design[[config$test_label_column]])) {
    stop(paste("Error: labelColumn", config$label_column, "not found"))
  } else {
    labels <- factor(full_design[[config$test_label_column]])
  }
  labels
}

#' @export
loadSubset <- function(full_design, subset) {
  if (is.character(subset)) {
    if (substr(subset, 1,1) != "~") {
      subset <- paste0("~", subset)
    }   
    subset <- eval(parse(text=subset))
  } 
  
  keep <- if(is.null(subset)) rep(TRUE, nrow(full_design)) else {  
    subexpr <- subset[[2]]   
    keep <- eval(subexpr, full_design)
    if (sum(keep) == nrow(full_design)) {
      warning(paste("subset has same number of rows as full table"))
    }
    
    keep
  }
  
  keep
  
}

#' @export
loadBlockColumn <- function(config, design) {
  if (is.null(design[[config$block_column]])) {
    abort(paste("blockColumn variable named", config$blockColumn, "not found."))
  } else {  
    config$nfolds <- length(unique(design[[config$block_column]]))
    design[[config$block_column]]
  }
   
}

#' @export
#' 
loadBrainDataSequence <- function(fnames, config, indices) {
  if (!all(file.exists(fnames))) {
    offenders <- fnames[!file.exists(fnames)]
    abort(config, paste("data files", offenders, "not found."))
  }
  
  
  ### TODO make more efficient. This loads in all data then subsets.
  vecmat <- do.call(rbind, lapply(1:length(fnames), function(i) {
    fname <- fnames[i]
    flog.info("loading data file %s", fname)
    mat <- neuroim::as.matrix(loadVector(fname, mask=config$maskVolume))
    flog.info("data file %s has %s voxels and %s samples", fname, ncol(mat), nrow(mat))
    mat
  }))
  
  SparseBrainVector(vecmat[indices,], space(config$maskVolume), mask=config$maskVolume)
}

#' @export
loadBrainData <- function(config, name, indices=NULL) {
  fname <- config[[name]]
  if (length(fname) > 1) {
    loadBrainDataSequence(fname, config, indices)
  } else if (!file.exists(fname)) {
    abort(config, paste("datafile", fname, "not found."))
  } else {
    flog.info("loading data file %s", fname)
    if (!is.null(indices)) {
      loadVector(fname, indices=indices, mask=config$maskVolume)
    } else {
      loadVector(fname, mask=config$maskVolume)
    }
    
  }
}


  