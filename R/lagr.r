#' Fit a lagr model
#'
#' \code{lagr} fits a model via local, adaptive, grouped regularization.
#'
#' This method fits a local model at each location indicated by \code{fit.loc}.
#'
#' @param formula A formula object describing the response and the predictor variables.
#' @param data A data frame containing the model-building data
#' @param family The exponential family (or Cox model) distribution of the response.
#' @param weights Prior weights on the observations. These aren't the kernel weights - those will be calculated internally.
#' @param coords The coordinates of theobservation locations. Rows of \code{coords} must align with rows of \code{data}.
#' @param fit.loc (optional) You can specify the locations to fit the local models via \code{fit.loc}. Otherwise, the locations in \code{coords} will be used.
#' @param longlat Are the coordinates provided in longitude and latitude? Default is \code{FALSE}.
#' @param kernel The kernel function to use for locally weighting observations.
#' @param bw The bandwidth to use with the kernel.
#' @param bw.type The type of bandwidth. \code{dist} means the bandwidth is a distance, \code{knn} means it is a proportion of the \code{n}, and \code{nen} means it is a proportion of the global-model sum of squared residuals.
#' @param varselect.method What criterion to minimize during variable selection. Options are \code{AIC}, \code{BIC}, \code{AICc}, and \code{GCV}.
#' @param resid.type What kind of residuals to use. Options are \code{pearson} and \code{deviance}.
#' 
#' @return models A list containing the local models.
#' 
#' @export
lagr <- function(formula, data, family=c('gaussian', 'binomial', 'poisson', 'Cox'), weights=NULL, coords, fit.loc=NULL, tuning=FALSE, predict=FALSE, simulation=FALSE, oracle=NULL, kernel, bw=NULL, varselect.method=c('AIC','BIC','AICc'), verbose=FALSE, longlat, tol.loc=NULL, bw.type=c('dist','knn','nen'), D=NULL, resid.type=c('deviance','pearson')) {

    #If the data was provided as a spatial data frame, then extract both the data and the coordinates.
    if (is(data, "Spatial")) {
        if (!missing(coords)) 
            warning("data is Spatial* object, ignoring coords argument")
        coords <- coordinates(data)
        if ((is.null(longlat) || !is.logical(longlat)) && !is.na(is.projected(data)) && 
            !is.projected(data)) {
            longlat <- TRUE
        }
        else longlat <- FALSE
        data <- as(data, "data.frame")
    }
    
    #Only interpret the coordinates as latitude/longitude values if the longlat variable is TRUE
    if (is.null(longlat) || !is.logical(longlat)) 
        longlat <- FALSE
    
    #Make sure coordinates were specified
    if (missing(coords)) 
        stop("Observation coordinates have to be given")
    
    #Check for problems with the (prior) weights
    if (!is.null(weights) && !is.numeric(weights)) 
      stop("'weights' must be a numeric vector")
    if (is.null(weights)) 
      weights <- rep(1, nrow(data))
    if (any(is.na(weights))) 
      stop("NAs in weights")
    if (any(weights < 0)) 
      stop("negative weights")
    
    #Extract the model matrix and the response using the formula and the data:
    mf <- match.call(expand.dots = FALSE)
print(names(mf))
    m <- match(c("formula", "data"), names(mf), 0)
    mf <- mf[c(1, m)]
    mf$drop.unused.levels <- TRUE
    mf[[1]] <- as.name("model.frame")
    mf <- eval(mf, parent.frame())
    mt <- attr(mf, "terms")
    dp.n <- length(model.extract(mf, "response"))

    #Here we set the variables that will be used to send the data out.
    y <- model.extract(mf, "response")
    x <- model.matrix(mt, mf)

    #Get the matrices of distances and weights
    D.coords = rbind(coords, fit.loc)
    if (is.null(D)) {
        n = nrow(D.coords)
        if (longlat) {
            D = as.matrix(earth.dist(D.coords),n,n)
        } else {
            Xmat = matrix(rep(D.coords[,1], times=n), n, n)
            Ymat = matrix(rep(D.coords[,2], times=n), n, n)
            D = sqrt((Xmat-t(Xmat))**2 + (Ymat-t(Ymat))**2)
        }
    }

    #Set some variables that determine how we fit the model
    resid.type = match.arg(resid.type)
    bw.type = match.arg(bw.type)
    varselect.method = match.arg(varselect.method)
    
    #Find the possible range of bandwidths (for use with the adaptive bandwith methods - knn or nen)
    bbox <- cbind(range(coords[, 1]), range(coords[, 2]))
    difmin <- spDistsN1(bbox, bbox[2, ], longlat)[1]
    if (any(!is.finite(difmin))) 
        difmin[which(!is.finite(difmin))] <- 0
    min.dist = difmin/300
    max.dist = 10*difmin

    #Fit the model:
    res = list()
    res[['model']] = lagr.dispatch(x=x,
                                    y=y,
                                    family=family,
                                    prior.weights=weights,
                                    tuning=tuning,
                                    predict=predict,
                                    simulation=simulation,
                                    coords=coords,
                                    oracle=oracle,
                                    fit.loc=fit.loc,
                                    D=D,
                                    longlat=longlat,
                                    varselect.method=varselect.method,
                                    verbose=verbose,
                                    target=bw,
                                    bw.type=bw.type,
                                    kernel=kernel,
                                    min.dist=min.dist,
                                    max.dist=max.dist,
                                    tol.loc=tol.loc,
                                    resid.type=resid.type)

    #Store results from model fitting:
    if (!tuning) {
        res[['data']] = data
        res[['response']] = as.character(formula[[2]])
        res[['family']] = family
        res[['weights']] = weights
        res[['coords']] = coords
        res[['fit.locs']] = fit.loc
        res[['longlat']] = longlat
        res[['kernel']] = kernel
        res[['bw']] = bw
        res[['bw.type']] = bw.type
        res[['varselect.method']] = varselect.method
    }
    class(res) = "lagr"

    res
}
