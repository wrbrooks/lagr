% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/lagr.tune.r
\name{lagr.tune}
\alias{lagr.tune}
\title{Estimate the bandwidth parameter for a lagr model}
\usage{
lagr.tune(formula, data, family = gaussian(), range = NULL,
  weights = NULL, coords, oracle = NULL, kernel = NULL,
  bw.type = c("dist", "knn", "nen"), varselect.method = c("AIC", "BIC",
  "AICc", "jacknife", "wAIC", "wAICc"), verbose = FALSE, longlat = FALSE,
  tol.loc = .Machine$double.eps^0.25, tol.bw = .Machine$double.eps^0.25,
  bwselect.method = c("AIC", "AICc", "GCV", "BIC"),
  lambda.min.ratio = 0.001, n.lambda = 50, lagr.convergence.tol = 0.001,
  lagr.max.iter = 20, na.action = na.fail, contrasts = NULL)
}
\arguments{
\item{formula}{symbolic representation of the model}

\item{data}{data frame containing observations of all the terms represented in the formula}

\item{family}{exponential family distribution of the response}

\item{range}{allowable range of the bandwidth}

\item{weights}{vector of prior observation weights (due to, e.g., overdispersion). Not related to the kernel weights.}

\item{coords}{matrix of locations, with each row giving the location at which the corresponding row of data was observed}

\item{kernel}{kernel function for generating the local observation weights}

\item{bw.type}{type of bandwidth - options are \code{dist} for distance (the default), \code{knn} for nearest neighbors (bandwidth a proportion of \code{n}), and \code{nen} for nearest effective neighbors (bandwidth a proportion of the sum of squared residuals from a global model)}

\item{varselect.method}{criterion to minimize in the regularization step of fitting local models - options are \code{AIC}, \code{AICc}, \code{BIC}, \code{GCV}}

\item{verbose}{print detailed information about our progress?}

\item{longlat}{\code{TRUE} indicates that the coordinates are specified in longitude/latitude, \code{FALSE} indicates Cartesian coordinates. Default is \code{FALSE}.}

\item{tol.loc}{local error tolerance for converting an adaptive bandwidth (e.g. \code{knn} or \code{nen}) to a distance}

\item{tol.bw}{global error tolerance for minimizing the bandwidth selection criterion}

\item{bwselect.method}{criterion to minimize when tuning bandwidth - options are \code{AICc}, \code{BICg}, and \code{GCV}}

\item{fit.loc}{matrix of locations where the local models should be fitted}

\item{bw}{bandwidth for the kernel}

\item{tuning}{logical indicating whether this model will be used to tune the bandwidth, in which case only the tuning criteria are returned}

\item{a}{pre-specified matrix of distances between locations}
}
\value{
\code{list(bw, trace)} where \code{bw} minimizes the bandwidth selection criterion and trace is a data frame of each bandwidth that was tried during the optimization, along with the resulting degrees of freedom used inthe LAGR model and the value of the bandwidth selection criterion.
}
\description{
\code{lagr.tune} estimates the bandwidth parameter for a LAGR model.
}
\details{
This method calls \code{lagr} repeatedly via the \code{optimize} function, searching for the bandwidth that minimizes a bandwidth selection criterion. It returns the profiled value of the selection criterion at each bandwidth that is used in the evaluation.
}

