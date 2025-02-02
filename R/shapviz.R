#' Initialize "shapviz" Object
#'
#' This function creates an object of class "shapviz" from one of the following inputs:
#' \itemize{
#'   \item Matrix with SHAP values
#'   \item XGBoost model
#'   \item LightGBM model
#'   \item "explain" object from the package "fastshap"
#'   \item H2O model (tree-based regression or binary classification model)
#'   \item "shapr" object from the package "shapr"
#'   \item The result of calling \code{treeshap()} from the "treeshap" package
#'   \item "kernelshap" object from the "kernelshap" package
#' }
#' The "shapviz" vignette explains how to use each of them.
#' Together with the main input, a data set \code{X} of feature values is required,
#' which is used only for visualization. It can therefore contain character or factor
#' variables, even if the SHAP values were calculated from a purely numerical feature
#' matrix. In addition, to improve visualization, it can sometimes be useful to truncate
#' gross outliers, logarithmize certain columns, or replace missing values with an
#' explicit value. SHAP values of dummy variables can be combined using the convenient
#' \code{collapse} argument.
#' @importFrom xgboost xgb.train
#' @param object Object to be converted to an object of type "shapviz".
#' @param X Corresponding matrix or data.frame of feature values used for visualization.
#' @param X_pred Data set as expected by the \code{predict} function of
#' XGBoost, LightGBM, or H2O. For XGBoost, a matrix or \code{xgb.DMatrix},
#' for LightGBM a matrix, and for H2O a \code{data.frame} or an \code{H2OFrame}.
#' @param baseline Optional baseline value, representing the average response at the
#' scale of the SHAP values. It will be used for plot methods that explain single
#' predictions.
#' @param which_class In case of a multiclass or multioutput setting,
#' which class/output (>= 1) to explain. Currently relevant for XGBoost, LightGBM,
#' or kernelshap.
#' @param collapse A named list of character vectors. Each vector specifies a group of
#' column names in the SHAP matrix that should be collapsed to a single column by summation.
#' The name of the new column equals the name of the vector in \code{collapse}.
#' @param ... Parameters passed to other methods (currently only used by
#' the \code{predict} functions of XGBoost, LightGBM, and H2O).
#' @return An object of class "shapviz" with the following three elements:
#' \itemize{
#'   \item \code{S}: A numeric matrix of SHAP values.
#'   \item \code{X}: A \code{data.frame} containing the feature values corresponding to \code{S}.
#'   \item \code{baseline}: Baseline value, representing the average prediction at the scale of the SHAP values.
#' }
#' @export
#' @seealso \code{\link{sv_importance}}, \code{\link{sv_dependence}},
#' \code{\link{sv_waterfall}}, \code{\link{sv_force}}, \code{\link{collapse_shap}}
#' @examples
#' S <- matrix(c(1, -1, -1, 1), ncol = 2, dimnames = list(NULL, c("x", "y")))
#' X <- data.frame(x = c("a", "b"), y = c(100, 10))
#' shapviz(S, X, baseline = 4)
#'
shapviz <- function(object, ...){
  UseMethod("shapviz")
}

#' @describeIn shapviz Default method to initialize a "shapviz" object.
#' @export
shapviz.default = function(object, ...) {
  stop("No default method available. shapviz() is available for objects
       of class 'matrix', 'xgb.Booster', 'lgb.Booster', 'treeshap',
       'shapr', 'H2OModel', 'explain' (from fastshap package), and 'kernelshap'.")
}

#' @describeIn shapviz Creates a "shapviz" object from a matrix of SHAP values.
#' @export
shapviz.matrix = function(object, X, baseline = 0, collapse = NULL, ...) {
  object <- collapse_shap(object, collapse = collapse)
  stopifnot(
    "'X' must be a matrix or data.frame" = is.matrix(X) || is.data.frame(X),
    "The number of rows of 'object' and 'X' differ" = nrow(object) == nrow(X),
    "The number of columns of 'object' and 'X' differ" = ncol(object) == ncol(X),
    "'X' and 'object' need at least one row and one column" = dim(X) >= 1L,
    "SHAP matrix must have column names" = !is.null(colnames(object)),
    "'X' must have column names" = !is.null(colnames(X)),
    "'object' and 'X' must have the same column names" =
      sort(colnames(object)) == sort(colnames(X)),
    "No missing SHAP values allowed" = !anyNA(object),
    "'baseline' has to be a single number" =
      length(baseline) == 1L && is.numeric(baseline),
    "'baseline' cannot be NA" = !is.na(baseline)
  )
  out <- list(
    S = object[, colnames(X), drop = FALSE],
    X = as.data.frame(X),
    baseline = baseline
  )
  class(out) <- "shapviz"
  out
}

#' @describeIn shapviz Creates a "shapviz" object from an XGBoost model.
#' @export
#' @examples
#' X_pred <- data.matrix(iris[, -1])
#' dtrain <- xgboost::xgb.DMatrix(X_pred, label = iris[, 1])
#' fit <- xgboost::xgb.train(data = dtrain, nrounds = 50)
#'
#' # Will use numeric matrix "X_pred" as feature matrix
#' x <- shapviz(fit, X_pred = X_pred)
#' sv_importance(x)
#'
#' # Will use original values as feature matrix
#' x <- shapviz(fit, X_pred = X_pred, X = iris[, -1])
#' sv_dependence(x, "Petal.Length", color_var = "auto")
#'
#' # "X_pred" can also be passed as xgb.DMatrix, but only if X is passed as well!
#' x <- shapviz(fit, X_pred = dtrain, X = iris[, -1])
#'
#' # Similarly with LightGBM
#' if (requireNamespace("lightgbm", quietly = TRUE)) {
#'   fit <- lightgbm::lgb.train(
#'     params = list(objective = "regression"),
#'     data = lightgbm::lgb.Dataset(X_pred, label = iris[, 1]),
#'     nrounds = 50,
#'     verbose = -2
#'   )
#'   x <- shapviz(fit, X_pred = X_pred)
#' }
#'
#' # In multiclass setting, we need to specify which_class (integer starting at 1)
#' params <- list(objective = "multi:softprob", num_class = 3)
#' X_pred <- data.matrix(iris[, -5])
#' dtrain <- xgboost::xgb.DMatrix(X_pred, label = as.integer(iris[, 5]) - 1L)
#' fit <- xgboost::xgb.train(params = params, data = dtrain, nrounds = 50)
#' x <- shapviz(fit, X_pred = X_pred, which_class = 3)
#'
#' # What if we would have one-hot-encoded values and want to explain the original column?
#' X_pred <- stats::model.matrix(~ . -1, iris[, -1])
#' dtrain <- xgboost::xgb.DMatrix(X_pred, label = as.integer(iris[, 1]))
#' fit <- xgboost::xgb.train(data = dtrain, nrounds = 50)
#' x <- shapviz(
#'   fit,
#'   X_pred = X_pred,
#'   X = iris[, -1],
#'   collapse = list(Species = c("Speciessetosa", "Speciesversicolor", "Speciesvirginica"))
#' )
shapviz.xgb.Booster = function(object, X_pred, X = X_pred,
                               which_class = NULL, collapse = NULL, ...) {
  stopifnot(
    "X must be a matrix or data.frame. It can't be an object of class xgb.DMatrix" =
      is.matrix(X) || is.data.frame(X),
    "X_pred must be a matrix or a xgb.DMatrix" =
      is.matrix(X_pred) || inherits(X_pred, "xgb.DMatrix"),
    "X_pred must have column names" = !is.null(colnames(X_pred))
  )

  S <- stats::predict(object, newdata = X_pred, predcontrib = TRUE, ...)

  # Multiclass
  if (is.list(S)) {
    stopifnot(!is.null(which_class), which_class <= length(S))
    S <- S[[which_class]]
  }

  # Call matrix method
  shapviz.matrix(
    S[, setdiff(colnames(S), "BIAS"), drop = FALSE],
    X = X,
    baseline = unname(S[1L, "BIAS"]),
    collapse = collapse
  )
}

#' @describeIn shapviz Creates a "shapviz" object from a LightGBM model.
#' @export
shapviz.lgb.Booster = function(object, X_pred, X = X_pred,
                               which_class = NULL, collapse = NULL, ...) {
  if (!requireNamespace("lightgbm", quietly = TRUE)) {
    stop("Package 'lightgbm' not installed")
  }
  stopifnot(
    "X_pred must be a matrix" = is.matrix(X_pred),
    "X_pred must have column names" = !is.null(colnames(X_pred))
  )

  # Switch for different versions of predict.lgb.Booster()
  is_v4 <- utils::packageVersion("lightgbm") >= 4
  has_type <- "type" %in% names(formals(utils::getS3method("predict", "lgb.Booster")))
  if (is_v4 || has_type) {
    S <- stats::predict(object, newdata = X_pred, type = "contrib", ...)
  } else {
    S <- stats::predict(object, X_pred, predcontrib = TRUE, ...)
  }

  pp <- ncol(X_pred) + 1L
  stopifnot(ncol(S) %% pp == 0)

  # Reduce multiclass setting
  m <- ncol(S) %/% pp
  if (m >= 2L) {
    stopifnot(!is.null(which_class), which_class <= m)
    S <- S[, 1:pp + pp * (which_class - 1), drop = FALSE]
  }

  # Call matrix method
  baseline <- S[1L, pp]
  S <- S[, -pp, drop = FALSE]
  colnames(S) <- colnames(X_pred)
  shapviz.matrix(S, X = X, baseline = baseline, collapse = collapse)
}

#' @describeIn shapviz Creates a "shapviz" object from fastshap's "explain()" method.
#' @export
shapviz.explain <- function(object, X, baseline = 0, collapse = NULL, ...) {
  shapviz.matrix(as.matrix(object), X = X, baseline = baseline, collapse = collapse)
}

#' @describeIn shapviz Creates a "shapviz" object from treeshap's "treeshap()" method.
#' @export
shapviz.treeshap <- function(object, X = object[["observations"]],
                             baseline = 0, collapse = NULL, ...) {
  shapviz.matrix(
    as.matrix(object[["shaps"]]),
    X = X,
    baseline = baseline,
    collapse = collapse
  )
}

#' @describeIn shapviz Creates a "shapviz" object from shapr's "explain()" method.
#' @export
shapviz.shapr <- function(object, X = object[["x_test"]], collapse = NULL, ...) {
  dt <- as.matrix(object[["dt"]])
  shapviz.matrix(
    dt[, setdiff(colnames(dt), "none"), drop = FALSE],
    X = X,
    baseline = dt[1L, "none"],
    collapse = collapse
  )
}

#' @describeIn shapviz Creates a "shapviz" object from kernelshap's "kernelshap()" method.
#' @export
shapviz.kernelshap <- function(object, X = object[["X"]],
                               which_class = NULL, collapse = NULL, ...) {
  S <- object[["S"]]
  b <- object[["baseline"]]

  # Multiclass/multioutput
  if (is.list(S)) {
    stopifnot(!is.null(which_class), which_class <= length(S))
    S <- S[[which_class]]
    b <- b[which_class]
  }

  shapviz.matrix(S, X = X, baseline = b, collapse = collapse)
}

#' @describeIn shapviz Creates a "shapviz" object from a (tree-based) H2O regression model.
#' @export
shapviz.H2ORegressionModel = function(object, X_pred,
                                      X = as.data.frame(X_pred)[object@parameters[["x"]]],
                                      collapse = NULL, ...) {
  shapviz.H2OModel(object = object, X_pred = X_pred, X = X, collapse = collapse, ...)
}

#' @describeIn shapviz Creates a "shapviz" object from a (tree-based) H2O binary classification model.
#' @export
shapviz.H2OBinomialModel = function(object, X_pred,
                                    X = as.data.frame(X_pred)[object@parameters[["x"]]],
                                    collapse = NULL, ...) {
  shapviz.H2OModel(object = object, X_pred = X_pred, X = X, collapse = collapse, ...)
}

#' @describeIn shapviz Creates a "shapviz" object from a (tree-based) H2O model (base class).
#' @export
shapviz.H2OModel = function(object, X_pred,
                            X = as.data.frame(X_pred)[object@parameters[["x"]]],
                            collapse = NULL, ...) {
  if (!requireNamespace("h2o", quietly = TRUE)) {
    stop("Package 'h2o' not installed")
  }
  stopifnot(
    "X_pred must be a data.frame or an H2OFrame" =
      is.data.frame(X_pred) || inherits(X_pred, "H2OFrame"),
    "X_pred must have column names" = !is.null(colnames(X_pred))
  )
  if (!inherits(X_pred, "H2OFrame")) {
    X_pred <- h2o::as.h2o(X_pred)
  }
  S <- as.matrix(h2o::h2o.predict_contributions(object, newdata = X_pred, ...))
  shapviz.matrix(
    S[, setdiff(colnames(S), "BiasTerm"), drop = FALSE],
    X = X,
    baseline = unname(S[1L, "BiasTerm"]),
    collapse = collapse
  )
}

#' Initialize "shapviz" Object from XGBoost/LightGBM Predict (Deprecated)
#'
#' These functions create an object of class "shapviz" by taking the output of
#' \code{predict(..., predcontrib = TRUE)} of an XGBoost or LightGBM model,
#' together with a matrix/data.frame \code{X} representing the corresponding
#' feature values. These functions are mainly written for internal use
#' but they can be useful if SHAP values have already been computed.
#' Note that the SHAP matrix returned by LightGBM does not provide column names.
#' Thus, you need to be absolutely sure that the column names of \code{X}
#' correspond to the column names originally passed to \code{predict()}.
#'
#' @param S Output of calling \code{predict(..., predcontrib = TRUE)}.
#' @param X Matrix or data.frame of feature values corresponding to \code{S}.
#' @param which_class In case of a multiclass setting, which class >= 1 to explain.
#' @param ... Other parameters passed (currently unused).
#' @return An object of class "shapviz".
#' @name from_xgb_or_lgb
NULL

#' @rdname from_xgb_or_lgb
#' @export
#' @examples
#' X_pred <- data.matrix(iris[, -1])
#' dtrain <- xgboost::xgb.DMatrix(X_pred, label = iris[, 1])
#' fit <- xgboost::xgb.train(data = dtrain, nrounds = 50)
#' shap_values <- predict(fit, dtrain, predcontrib = TRUE)
#' x <- shapviz_from_xgb_predict(shap_values, iris[, -1])
shapviz_from_xgb_predict <- function(S, X, which_class = NULL, ...) {
  warning("This function is deprecated and will be removed in version 0.3.0.")
  # Reduce multiclass setting
  if (is.list(S)) {
    m <- length(S)
    stopifnot(
      !is.null(which_class),
      which_class <= m
    )
    S <- S[[which_class]]
  }
  stopifnot(
    is.matrix(S),
    is.matrix(X) || is.data.frame(X),
    nrow(S) == nrow(X),
    ncol(S) == ncol(X) + 1L,
    !is.null(colnames(S)),
    !is.null(colnames(X)),
    sort(colnames(S)) == sort(c(colnames(X), "BIAS"))
  )
  shapviz.matrix(
    S[, colnames(X), drop = FALSE],
    X = X,
    baseline = unname(S[1L, "BIAS"])
  )
}

#' @rdname from_xgb_or_lgb
#' @export
shapviz_from_lgb_predict <- function(S, X, which_class = NULL, ...) {
  warning("This function is deprecated and will be removed in version 0.3.0.")
  pp <- ncol(X) + 1L
  stopifnot(
    is.matrix(S),
    is.matrix(X) || is.data.frame(X),
    nrow(S) == nrow(X),
    ncol(S) %% pp == 0,
    !is.null(colnames(X))
  )
  # Reduce multiclass setting
  m <- ncol(S) %/% pp
  if (m >= 2L) {
    stopifnot(
      !is.null(which_class),
      which_class <= m
    )
    S <- S[, 1:pp + pp * (which_class - 1), drop = FALSE]
  }
  baseline <- S[1L, pp]
  S <- S[, -pp, drop = FALSE]
  colnames(S) <- colnames(X)
  shapviz.matrix(S, X = X, baseline = baseline)
}
