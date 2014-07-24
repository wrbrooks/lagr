#include <Rcpp11>
#include <iostream>
#include <math.h>
#include <numeric>

using namespace Rcpp;
using namespace std;



//////////////////////////////////
// [[Rcpp::export]]
void identityLinkCpp(NumericVector eta, NumericVector expect)
{
    for (int i=0; i<eta.size(); i++)
    {
        expect[i] = eta[i];
    }
}

// [[Rcpp::export]]
typedef void (*funcPtr)(NumericVector eta, NumericVector expect); 
XPtr<funcPtr> Identity()
{
    return(XPtr<funcPtr>(new funcPtr(&identityLinkCpp)));
}


// [[Rcpp::export]]
double linLogLik(NumericVector expect, NumericVector y, NumericVector w)
{
    double squareSum = 0.5 * sum(w*pow(expect - y, 2));
    return squareSum / sum(w);
}


//This function returns the weighted mean of the difference between eta and y
void rcppLinGradCalc(NumericVector expect, NumericVector y, NumericVector w, NumericVector ldot)
{
    double sumw = sum(w);
    ldot = w * (expect - y)/sumw;
}


//Returns the weighted sum of squared residuals.
double rcppLinNegLogLikelihoodCalc(NumericVector expect, NumericVector y, NumericVector w)
{
    double squareSum = 0.5 * sum(w*pow(expect - y, 2));
    return squareSum / sum(w);
}


void rcppLinSolver(NumericMatrix X, NumericVector y, NumericVector w, NumericVector adaweights, int nrow, int ncol, int numGroup, NumericMatrix beta, Function link, Function loglik, IntegerVector rangeGroupInd, IntegerVector groupLen, NumericVector lambda, int step, int innerIter, double thresh, NumericVector ldot, NumericVector nullBeta, double gamma, NumericVector eta, IntegerVector betaIsZero, int& groupChange, IntegerVector isActive, IntegerVector useGroup, double momentum, int reset)
{
    NumericVector theta(ncol);
    int startInd = 0;
    double zeroCheck = 0;
    double check = 0;
    int count = 0;
    double t = momentum;
    double diff = 1;
    double norm = 0;
    double uOp = 0;
    double Lnew = 0;
    double Lold = 0;
    double sqNormG = 0;
    double iProd = 0;
    NumericVector etaNew(nrow);
    NumericVector etaNull(nrow);
    NumericVector expect(nrow);
    NumericVector var(nrow);
    
    //funcPtr varianceFunction = *variance;
    //funcPtr linkFunction = *link;
    
    for(int i = 0; i < numGroup; i++)
    {
        if(useGroup[i] == 1)
        {
            startInd = rangeGroupInd[i];
            
            // Setting up null gradient calc to check if group is 0
            for(int k = 0; k < nrow; k++)
            {
                etaNull[k] = eta[k];
                for(int j = startInd; j < rangeGroupInd[i] + groupLen[i]; j++)
                {
                    etaNull[k] = etaNull[k] - X[k + nrow * j] * beta[step*ncol + j]; 
                }
            }
            
            // Calculating Null Gradient
            link(etaNull, expect);
            rcppLinGradCalc(expect, y, w, ldot);
            
            NumericVector grad(groupLen[i]);
            for(int j = 0; j < groupLen[i]; j++)
            {
                grad[j] = 0;
                for(int k = 0; k < nrow; k++)
                {
                    grad[j] = grad[j] + X[k + nrow * (j + rangeGroupInd[i])] * ldot[k];
                }
            }
            
            zeroCheck = sum(pow(grad,2));
            
            if(zeroCheck <= pow(adaweights[i],2)*pow(lambda[step],2)*groupLen[i])  //Or not?
            {
                if(betaIsZero[i] == 0)
                {
                    for(int k = 0; k < nrow; k++)
                    {
                        for(int j = rangeGroupInd[i]; j < rangeGroupInd[i] + groupLen[i]; j++)
                        {
                            eta[k] = eta[k] - X[k + nrow * j] * beta[step*ncol + j];
                        }
                    }
                }
                betaIsZero[i] = 1;
                for(int j = 0; j < groupLen[i]; j++)
                {
                    beta[step*ncol + j + rangeGroupInd[i]] = 0;
                }
            }
            else
            {
                if(isActive[i] == 0)
                {
                    groupChange = 1;
                }
                isActive[i] = 1;
                
                for(int k = 0; k < ncol; k++)
                {
                    theta[k] = beta[step*ncol + k];
                }
                
                betaIsZero[i] = 0;
                NumericVector z(groupLen[i]);
                NumericVector U(groupLen[i]);
                NumericVector G(groupLen[i]);
                NumericVector betaNew(ncol);
                
                count = 0;
                check = 100000;
                
                while(count <= innerIter && check > thresh)
                {
                    count++;
                    
                    link(eta, expect);
                    rcppLinGradCalc(expect, y, w, ldot);
                    
                    for(int j = 0; j < groupLen[i]; j++)
                    {          
                        grad[j] = 0;
                        for(int k = 0; k < nrow; k++)
                        {
                            grad[j] = grad[j] + X[k + nrow * (j + rangeGroupInd[i])] * ldot[k];
                        }
                    }
                    
                    diff = -1;
                    
                    link(eta, expect);
                    Lold = as<double>(loglik(expect, y, w));
                    //Lold = rcppLinNegLogLikelihoodCalc(expect, y, w);
                    
                    // Back-tracking
                    while(diff < 0)
                    {
                        for(int j = 0; j < groupLen[i]; j++)
                        {
                            z[j] = beta[step*ncol + j + rangeGroupInd[i]] - t * grad[j];
                        }
                        
                        norm = sum(pow(z, 2));
                        norm = sqrt(norm);
                        
                        if(norm != 0){
                            uOp = (1 - adaweights[i]*lambda[step]*sqrt(double(groupLen[i]))*t/norm);   //Or not?
                        }
                        else{uOp = 0;}
                        
                        if(uOp < 0)
                        {
                            uOp = 0;
                        }
                        
                        for(int j = 0; j < groupLen[i]; j++)
                        {
                            U[j] = uOp*z[j];
                            G[j] = 1/t *(beta[step*ncol + j + rangeGroupInd[i]] - U[j]);
                        }
                        
                        // Setting up betaNew and etaNew in direction of Grad for descent momentum
                        for(int k = 0; k < nrow; k++)
                        {
                            etaNew[k] = eta[k];
                            for(int j = 0; j < groupLen[i]; j++)
                            {
                                etaNew[k] = etaNew[k] - t*G[j] * X[k + nrow*(rangeGroupInd[i] + j)];
                            }
                        }
                        
                        link(etaNew, expect);
                        Lnew = as<double>(loglik(expect, y, w));
                        //Lnew = rcppLinNegLogLikelihoodCalc(expect, y, w);
                        
                        sqNormG = sum(pow(G, 2));
                        iProd = sum(grad * G);
                        
                        diff = Lold - Lnew - t * iProd + t/2 * sqNormG;
                        
                        t = t * gamma;
                    }
                    t = t / gamma;
                    
                    check = 0;
                    
                    for(int j = 0; j < groupLen[i]; j++)
                    {
                        check = check + fabs(theta[j + rangeGroupInd[i]] - U[j]);
                        for(int k = 0; k < nrow; k++)
                        {
                            eta[k] = eta[k] - X[k + nrow * (j + rangeGroupInd[i])]*beta[step*ncol + j + rangeGroupInd[i]];
                        }
                        beta[step*ncol + j + rangeGroupInd[i]] = U[j] + count%reset/(count%reset+3) * (U[j] - theta[j + rangeGroupInd[i]]);
                        theta[j + rangeGroupInd[i]] = U[j];
                        
                        for(int k = 0; k < nrow; k++)
                        {
                            eta[k] = eta[k] + X[k + nrow * (j + rangeGroupInd[i])]*beta[step*ncol + j + rangeGroupInd[i]];
                        }
                    }
                }
            }
        }
    }
}



// [[Rcpp::export]]
int rcppLinNest(NumericMatrix X, NumericVector y, NumericVector w, NumericVector adaweights, Function link, Function loglik, int nrow, int ncol, int numGroup, IntegerVector rangeGroupInd, IntegerVector groupLen, NumericVector lambda, NumericMatrix beta, int innerIter, int outerIter, double thresh, double outerThresh, NumericVector eta, double gamma, IntegerVector betaIsZero, double momentum, int reset)
{
    NumericVector prob(nrow);
    NumericVector nullBeta(ncol);
    int n = nrow;
    int p = ncol;
    NumericVector ldot(n);
    IntegerVector isActive(numGroup);
    IntegerVector useGroup(numGroup);
    IntegerVector tempIsActive(numGroup);
    int nlam = lambda.size();
    
    for (int step=0; step<nlam; step++)
    {
        for(int i=0; i<numGroup; i++)
        {
            isActive[i] = 0;
            useGroup[i] = 1;
        }
        
        //Copy the most recent betas into position
        if (step>0)
        {
            int l = step - 1;
            
            for (int i=0; i<ncol; i++)
            {
                beta[step*ncol + i] = beta[l*ncol + i];
            }
        }
        
        //Resolve pointers to the link and variance functions:
        //XPtr<funcPtr> linkFunction(link);
        //XPtr<funcPtr> varianceFunction(variance);
        
        // outer most loop creating response etc...
        int outermostCounter = 0;
        double outermostCheck = 100000;
        NumericVector outerOldBeta(p);
        int groupChange = 1;
            
        while(groupChange == 1)
        {
            groupChange = 0;
            
            rcppLinSolver(X, y, w, adaweights, nrow, ncol, numGroup, beta, link, loglik, rangeGroupInd, groupLen, lambda, step, innerIter, thresh, ldot, nullBeta, gamma, eta, betaIsZero, groupChange, isActive, useGroup, momentum, reset);
            
            while(outermostCounter < outerIter && outermostCheck > outerThresh)
            {
                outermostCounter ++;
                for(int i=0; i<p; i++)
                {
                    outerOldBeta[i] = beta[step*ncol + i];
                }
                
                for(int i=0; i<numGroup; i++)
                {
                    tempIsActive[i] = isActive[i];
                }
                
                rcppLinSolver(X, y, w, adaweights, nrow, ncol, numGroup, beta, link, loglik, rangeGroupInd, groupLen, lambda, step, innerIter, thresh, ldot, nullBeta, gamma, eta, betaIsZero, groupChange, isActive, tempIsActive, momentum, reset);
                
                outermostCheck = 0;
                for(int i=0; i<p; i++)
                {
                    outermostCheck = outermostCheck + fabs(outerOldBeta[i] - beta[step*ncol + i]);
                }
            }
        }
    }
    return 1;
}
