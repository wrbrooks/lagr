#' Evaluate the bandwidth selection criterion for a given bandwidth
#' 
#' @param formula symbolic representation of the model
#' @param data data frame containing observations of all the terms represented in the formula
#' @param weights vector of prior observation weights (due to, e.g., overdispersion). Not related to the kernel weights.
#' @param family exponential family distribution of the response
#' @param bw bandwidth for the kernel
#' @param kernel kernel function for generating the local observation weights
#' @param coords matrix of locations, with each row giving the location at which the corresponding row of data was observed
#' @param longlat \code{TRUE} indicates that the coordinates are specified in longitude/latitude, \code{FALSE} indicates Cartesian coordinates. Default is \code{FALSE}.
#' @param varselect.method criterion to minimize in the regularization step of fitting local models - options are \code{AIC}, \code{AICc}, \code{BIC}, \code{GCV}
#' @param tol.loc tolerance for the tuning of an adaptive bandwidth (e.g. \code{knn} or \code{nen})
#' @param bw.type type of bandwidth - options are \code{dist} for distance (the default), \code{knn} for nearest neighbors (bandwidth a proportion of \code{n}), and \code{nen} for nearest effective neighbors (bandwidth a proportion of the sum of squared residuals from a global model)
#' @param bwselect.method criterion to minimize when tuning bandwidth - options are \code{AICc}, \code{BICg}, and \code{GCV}
#' @param resid.type type of residual to use (relevant for non-gaussian response) - options are \code{deviance} and \code{pearson}
#' @param verbose print detailed information about our progress?
#' 
#' @return value of the \code{bwselect.method} criterion for the given bandwidth
#' 
lagr.tune.bw = function(x, y, weights, coords, dist, family, bw, kernel, env, oracle, varselect.method, tol.loc, bw.type, bwselect.method, min.dist, max.dist, resid.type, verbose) {    
    #Fit the model with the given bandwidth:
    cat(paste("starting bw:", round(bw, 3), '\n', sep=''))
    
    lagr.model = lagr.dispatch(
        x=x,
        y=y,
        coords=coords,
        fit.loc=NULL,
        D=dist,
        family=family,
        prior.weights=weights,
        tuning=TRUE,
        predict=FALSE,
        simulation=FALSE,
        oracle=oracle,
        varselect.method=varselect.method,
        verbose=verbose,
        bw=bw,
        bw.type=bw.type,
        kernel=kernel,
        min.dist=min.dist,
        max.dist=max.dist,
        tol.loc=tol.loc,
        resid.type=resid.type
    )
    
    #Compute the loss at this bandwidth
    if (bwselect.method=='AICc') {
        trH = sum(sapply(lagr.model, function(x) tail(x[['tunelist']][['df-local']],1)))
        loss = nrow(x) * (log(mean(sapply(lagr.model, function(x) x[['tunelist']][['ssr-loc']][[resid.type]]))) + log(2*pi) + 1) + (2*(trH+1)) / (nrow(x)-trH-2)
    } else if (bwselect.method=='AIC') {
        trH = sum(sapply(lagr.model, function(x) tail(x[['tunelist']][['df-local']],1)))
        loss = nrow(x) * (log(mean(sapply(lagr.model, function(x) x[['tunelist']][['ssr-loc']][[resid.type]]))) + log(2*pi) + 1) + 2*trH
    } else if (bwselect.method=='GCV') {
        trH = sum(sapply(lagr.model, function(x) tail(x[['tunelist']][['trace-local']],1))) 
        loss = sum(sapply(lagr.model, function(x) x[['tunelist']][['ssr-loc']][[resid.type]])) / (nrow(x)-trH)**2
    } else if (bwselect.method=='BICg') {
        trH = sum(sapply(lagr.model, function(x) {
            s2 = x[['tunelist']][['s2']]
            if (family=='gaussian') { ll = min(x[['tunelist']][['ssr-loc']][[resid.type]])/s2 + log(s2) }
            else if (family=='binomial') { ll = min(x[['tunelist']][['ssr-loc']][[resid.type]]) }
            else if (family=='poisson') { ll = min(x[['tunelist']][['ssr-loc']][[resid.type]])/s2 }
            df = x[['tunelist']][['df']]
            return(ll + log(x[['tunelist']][['n']]) * df / x[['tunelist']][['n']])
        }))
        loss = trH + sum(sapply(lagr.model, function(x) min(x[['tunelist']][['ssr-loc']][[resid.type]])))
        #"Simplistic" BIC - based on eq4.22 from the Fotheringham et al. book:
        #loss = nrow(x) * (log(mean(sapply(lagr.model, function(x) {x[['ssr.local']]}))) + 1 + log(2*pi)) + trH * log(nrow(x))/2
    }
    
    res = mget('trace', env=env, ifnotfound=list(matrix(NA, nrow=0, ncol=3)))
    res$trace = rbind(res$trace, c(bw, loss, trH))
    assign('trace', res$trace, env=env)
    
    cat(paste('Bandwidth: ', round(bw, 3), '. df: ', round(trH,4), '. Loss: ', signif(loss, 5), '\n', sep=''))
    return(loss)
}