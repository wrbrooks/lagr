% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/lagr.ssr.R
\name{lagr.ssr}
\alias{lagr.ssr}
\title{Calculate the sum of squared residuals for a local model}
\usage{
lagr.ssr(bw, x, y, group.id, family, loc, coords, dist, kernel, target,
  varselect.method, prior.weights, oracle, verbose, lambda.min.ratio, n.lambda,
  lagr.convergence.tol, lagr.max.iter)
}
\arguments{
\item{bw}{kernel bandwidth (distance) to use for fitting the local model}

\item{x}{matrix of observed covariates}

\item{y}{vector of observed responses}

\item{family}{exponential family distribution of the response}

\item{loc}{location around which to center the kernel}

\item{coords}{matrix of locations, with each row giving the location at which the corresponding row of data was observed}

\item{dist}{vector of distances from central location to the observation locations}

\item{kernel}{kernel function for generating the local observation weights}

\item{varselect.method}{criterion to minimize in the regularization step of fitting local models - options are \code{AIC}, \code{AICc}, \code{BIC}, \code{GCV}}

\item{verbose}{print detailed information about our progress?}

\item{longlat}{\code{TRUE} indicates that the coordinates are specified in longitude/latitude, \code{FALSE} indicates Cartesian coordinates. Default is \code{FALSE}.}

\item{bw}{bandwidth parameter}

\item{bw.type}{type of bandwidth - options are \code{dist} for distance (the default), \code{knn} for nearest neighbors (bandwidth a proportion of \code{n}), and \code{nen} for nearest effective neighbors (bandwidth a proportion of the sum of squared residuals from a global model)}

\item{tol.loc}{tolerance for the tuning of an adaptive bandwidth (e.g. \code{knn} or \code{nen})}

\item{tuning}{logical indicating whether this model will be used to tune the bandwidth, in which case only the tuning criteria are returned}

\item{D}{pre-specified matrix of distances between locations}
}
\description{
This function fits a local LAGR model at \code{loc}, and returns its sum of squared residuals (SSR) as a proportion of the SSR from a global model. This proportion is how the bandwidth is specified under \code{nen}.
}

