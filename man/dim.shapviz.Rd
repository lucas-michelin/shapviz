% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/shapviz_methods.R
\name{dim.shapviz}
\alias{dim.shapviz}
\title{Dimensions of "shapviz" Object}
\usage{
\method{dim}{shapviz}(x)
}
\arguments{
\item{x}{A on object of class "shapviz".}
}
\value{
A numeric vector of length two providing the number of rows and columns
of the SHAP matrix (or the feature dataset) stored in \code{x}.
}
\description{
Dimensions of "shapviz" Object
}
\examples{
S <- matrix(c(1, -1, -1, 1), ncol = 2, dimnames = list(NULL, c("x", "y")))
X <- data.frame(x = c("a", "b"), y = c(100, 10))
dim(shapviz(S, X))
}
\seealso{
\code{\link{shapviz}}.
}
