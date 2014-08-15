#' Compute the lambdas (adaptive group lasso tuning parameters) at which the local model will be fitted. 
#' 
#' Finds \code{lambda.max}, the smallest lambda that shrinks all the penalized groups to zero. The rest of the lambdas form a log-linear sequence from \code{lambda.max} to \code{lambda.min = min.frac*lambda.max}.
#'
#' @param data list consisting of \code{x}, a matrix of grouped lcoal covariates, and \code{y}, the vector of observed responses
#' @param index vector indicating group membership for each column of \code{x}
#' @param weights vector of observations weights
#' @param adaweights vector of adaptive group penalty multipliers (computed from the unpenalized coefficients)
#' @param min.frac ratio of \code{lambda.max} to \code{lambda.min}
#' @param nlam how many lambdas to compute along the sequence from \code{lambda.max} to \code{lambda.min}
#' @param type string indicating the kind of regression model, defaults to \code{"linear"}
#' 
#' @return vector of adaptive group lasso tuning parameters at which to compute the local LAGR coefficients
#' 
grouplassoLambdas <- function(data, index, family, weights, adaweights, min.frac=0.05, nlam=20, type="linear") {
    reset <- 10
    step <- 1
    gamma <- 0.8
    
    inner.iter <- 1000
    outer.iter <- 1000
    thresh = 10^(-3)
    outer.thresh = thresh
    
    n <- nrow(data$x)
    X <- data$x
    y <- data$y
    n <- nrow(X)
    p <- ncol(X)
    
    #put the groups and adaweights in numerical order
    groups <- unique(index)
    ord.g = order(groups)
    groups = groups[ord.g]
    adaweights = adaweights[ord.g]
    
    #Reorder columns of X so that groups are contiguous
    ord <- order(index)
    index <- index[ord]
    X <- X[,ord]
    unOrd <- match(1:length(ord),ord)
    
    ## Coming up with other C++ info ##        
    num.groups <- length(groups)
    range.group.ind <- rep(0,(num.groups+1))
    for (i in 1:num.groups) {
        range.group.ind[i] <- min(which(index == groups[i])) - 1
    }
    range.group.ind[num.groups + 1] <- ncol(X)
    group.length <- diff(range.group.ind)
    
    #Find the largest penalty for which each group would appear in the model, if it were the only penalized group:
    lambda.max <- rep(0,num.groups)
    
    #Unpenalized groups should appear for any value of lambda:
    unpen = groups[which(adaweights==0)]
    indx.unpen = which(index == unpen)
    n.unpen = length(indx.unpen)
    
    for (i in 1:num.groups) {
        if (adaweights[i] > 0) {
            ind <- groups[i]
            n.pen = length(ind)
            X.fit <- X[,c(which(index == ind), indx.unpen), drop=FALSE]
            
            m = glm.fit(y=y, x=X.fit, weights=weights, family=family, intercept=FALSE)
            XtX = t(m$R) %*% m$R
            cors = (XtX %*% m$coef / adaweights[i])[1:n.pen]
            #cors <- t(X.fit) %*% diag(weights) %*% resp / adaweights[i]
            lambda.max[i] <- sqrt(sum(cors^2)) / sqrt(group.length[i])
        }
    }
    
    max.lam <- max(lambda.max) * 1.1 #The factor of 1.1 is to make sure the first lambda has only unpenalized covariates.
    min.lam <- min.frac * max.lam
    lambdas <- exp(seq(log(max.lam), log(min.lam), length.out=nlam))
    return(lambdas/sum(weights))
}
