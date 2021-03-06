#' Fit a local model via the local adaptive group lasso
#' 
#' This function augments the covariates with local interactions, drops
#' observations with zero weight, runs the adaptive grouped lasso, computes the
#' residuals, and returns the necessary values for tuning or reporting.
#' 
#' @param x matrix of observed covariates
#' @param y vector of observed responses
#' @param loc location at which to fit a model
#' @param family exponential family distribution of the response
#' @param varselect.method criterion to minimize in the regularization step of
#'   fitting local models - options are \code{AIC}, \code{AICc}, \code{BIC},
#'   \code{GCV}
#' @param tuning logical indicating whether this model will be used to tune the
#'   bandwidth, in which case only the tuning criteria are returned
#' @param kernel.weights vector of observation weights from the kernel
#' @param prior.weights vector of prior observation weights provided by the user
#' @param longlat \code{TRUE} indicates that the coordinates are specified in
#'   longitude/latitude, \code{FALSE} indicates Cartesian coordinates. Default
#'   is \code{FALSE}.
#'   
#' @return list of coefficients, nonzero coefficient identities, and tuning data
#' @useDynLib lagr 
#'
lagr.fit.inner = function(x, y, group.id, coords, loc, family, varselect.method, oracle, tuning, predict, simulation, n.lambda, lambda.min.ratio, lagr.convergence.tol, lagr.max.iter, verbose, kernel.weights=NULL, prior.weights=NULL, longlat=FALSE) {
    #Find which observations were made at the model location  
    colocated = which(apply(coords, 1, function(cc) all(round(cc,5) == round(as.numeric(loc),5))))

    #Bail now if only one observation has weight:
    if (sum(kernel.weights)==length(colocated)) {
        return(list('tunelist'=list('df-local'=1, 'ssr-loc'=list('pearson'=Inf, 'deviance'=Inf))))
    }
    
    #Use oracular variable selection if specified
    orig.names = colnames(x)
    if (!is.null(oracle)) {
        x = matrix(x[,oracle], nrow=nrow(x), ncol=length(oracle))
        colnames(x) = oracle
    }

    #Establish groups for the group lasso and if there's an intercept, mark it as unpenalized
    if (0 %in% group.id)
        unpen = 0
    raw.vargroup = group.id
    
    #This is the naming system for the covariate-by-location interaction variables.
    raw.names = colnames(x)
    interact.names = vector()
    for (l in 1:length(raw.names)) {
        for (m in 1:ncol(coords)) {
            interact.names = c(interact.names, paste(raw.names[l], ":", colnames(coords)[m], sep=""))
        }
    }

    #Compute the covariate-by-location interactions
    q = ncol(coords)
    interacted = matrix(0, ncol=q*ncol(x), nrow=nrow(x))
    for (k in 1:ncol(x)) {
        for (ll in 1:q) {
            interacted[,q*(k-1)+ll] = x[,k, drop=FALSE]*(coords[,ll]-loc[[ll]])
            group.id = c(group.id, group.id[k])
        }
    }
    x.interacted = cbind(x, interacted)
    colnames(x.interacted) = c(raw.names, interact.names)

    #Combine prior weights and kernel weights
    w <- prior.weights * kernel.weights
    weighted = which(w>0)
    n.weighted = length(weighted)

    #Limit our attention to the observations with nonzero weight
    xxx = as.matrix(x.interacted[weighted,, drop=FALSE])
    yyy = as.matrix(y[weighted])
    colocated = which(kernel.weights[weighted]==1)
    w = w[weighted]
    sumw = sum(w)
    
    #Instantiate objects to store our output
    tunelist = list()

    if (is.null(oracle)) {
        #Use the adaptive group lasso to produce a local model:
        model = grouplasso(data=list(x=xxx, y=yyy), weights=w, index=group.id, family=family, maxit=lagr.max.iter, delta=2, nlam=n.lambda, min.frac=lambda.min.ratio, thresh=lagr.convergence.tol, unpenalized=unpen)

        vars = apply(as.matrix(model$beta), 2, function(x) {which(x!=0)})
        df = model$results$df + 1 #Add one because we must estimate the scale parameter.
    } else {
        model = glm(yyy~xxx-1, weights=w, family=family)
        vars = list(1:ncol(xxx))
        varset = vars[[1]]
        df = ncol(xxx) + 1 #Add one for the scale parameter
        
        fitted = model$fitted
        localfit = fitted[colocated]
        dispersion = summary(model)$dispersion
        k = 1

        #Estimating scale in penalty formula:
        loss = sumw * log(sum(w * model$residuals**2)) - log(sumw) + 1
    }

    if (sumw > ncol(x)) {
        if (is.null(oracle)) {
            #Extract the fitted values for each lambda:
            dispersion = model$results$dispersion

            #Using the grouplasso's criteria:
            loss = model$results[[varselect.method]]
                
            #Pick the lambda that minimizes the loss:
            k = which.min(loss)
            localfit = model$results$fitted[colocated,]
            df = df[k]
            if (k > 1) {
                varset = vars[[k]]
            } else {
                varset = NULL
            }
        }      
            
        #Prepare some outputs for the bandwidth-finding scheme:
        tunelist[['localfit']] = localfit
        tunelist[['criterion']] = model$results[[varselect.method]]
        tunelist[['dispersion']] = dispersion
        tunelist[['n']] = sumw
        tunelist[['df']] = df
        tunelist[['df-local']] = length(colocated) * df / sumw
                  
    } else {
        fitted = rep(meany, nrow(xxx))
        dispersion = 0
        loss = Inf
        loss.local = c(Inf)   
        localfit = meany
    }
    
    #Get the coefficients:
    if (is.null(oracle)) {
        coefs = drop(model$beta)
        rownames(coefs) = colnames(xxx)

        #Use AIC weights, or not:
        if (varselect.method %in% c('wAIC','wAICc')) {
            #Big average based on a selection criterion:
            w = -model$results[[varselect.method]]
            w = matrix(w / sum(w))
            #coefs = (model$beta %*% w)[1:length(orig.names)]
            #conf.zero = drop((model$beta==0) %*% w)[1:length(orig.names)]
            coefs = drop(model$beta %*% w)
            conf.zero = drop((model$beta==0) %*% w)
        } else {
            #coefs = model$beta[1:length(orig.names),k]
            coefs = model$beta[,k]
            conf.zero = as.numeric(coefs==0)
            names(conf.zero) = names(coefs)
        }

        #list the covariates that weren't shrunk to zero, but don't bother listing the intercept.
        nonzero = raw.names[which(raw.vargroup %in% unique(group.id[which(conf.zero!=1)]))]
        nonzero = nonzero[nonzero != "(Intercept)"]

        #names(coefs) = raw.names
        #names(conf.zero) = colnames(raw.names)  
        #names(coefs) = colnames(xxx)
        #names(conf.zero) = colnames(xxx)    
    } else {
        #coefs = rep(0, length(orig.names))
        #names(coefs) = orig.names
        coefs = rep(0, ncol(xxx))
        names(coefs) = colnames(xxx)
        coefs[raw.names] = coef(model)[1:length(oracle)]
        nonzero = raw.names
        conf.zero = rep(0, length(orig.names))
        names(conf.zero) = colnames(raw.names)
    }
    
  
    if (tuning) {
        return(list(tunelist=tunelist, model=model, s=k, dispersion=dispersion, nonzero=nonzero, weightsum=sumw, loss=loss))
    } else if (predict) {
        return(list(tunelist=tunelist, coef=coefs, weightsum=sumw, s=k, dispersion=dispersion, nonzero=nonzero, conf.zero=conf.zero))
    } else if (simulation) {
        return(list(tunelist=tunelist, coef=coefs, s=k, dispersion=dispersion, fitted=localfit, nonzero=nonzero, conf.zero=conf.zero, actual=yyy[colocated], weightsum=sumw, loss=loss))
    } else {
        return(list(model=model, loss=loss, coef=coefs, nonzero=nonzero, conf.zero=conf.zero, s=k, loc=loc, df=df, loss.local=loss, dispersion=dispersion, fitted=localfit, weightsum=sumw, tunelist=tunelist))
    }
}
