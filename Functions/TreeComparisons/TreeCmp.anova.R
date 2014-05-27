##########################
#Anova on TreeCmp analysis
##########################
#Performs an anova on a 'TreeCmp' object (parametric or non-parametric)
#Performs a TukeyHSD if a posthoc difference is significant (parametric or non-parametric)
#v.0.2
#Update: automatic parametric/non-parametric test (and possibility to save the results)
##########################
#SYNTAX :
#<data> an object of the class 'TreeCmp'
#<metric> the name of the metric of interest
#<plot> whether to plot the distribution of the metric as a boxplot (default=FALSE)
#<LaTeX> whether to output a LaTeX table (default=FALSE)
#<save.test> whether to save the details of the various parametric/non-parametric tests (default=FALSE)
##########################
#----
#guillert(at)tcd.ie - 27/05/2014
##########################
#Requirements:
#-R 3
#-R package 'xtable' [optional]
#-R package 'pgirmess' DEVELOPEMENT VERSION ONLY
##########################

TreeCmp.anova<-function(TreeCmp, metric, plot=FALSE, LaTeX=FALSE, save.test=FALSE) {

warning("Non-parametric test in development only!")

#HEADER

#DATA INPUT

    #TreeCmp
    if(class(TreeCmp) != 'TreeCmp') {
        stop('The input must be a "TreeCmp" class object')
    } else {
        length.TreeCmp<-length(TreeCmp) #The number of comparisons
        columns.TreeCmp<-length(TreeCmp[[1]]) #The number of columns per comparisons (i.e. the number of metrics)
        replicates.TreeCmp<-length(TreeCmp[[1]][[1]]) #The number of replicates per comparison
    }

    #metric
    if(class(metric) != 'character') {
        stop('Provided metric name is not found in the "TreeCmp" object')
    } else {
        if(length(metric) != 1) {
            stop('Only one metric name can be provided')
        } else {
            metric.column<-grep(metric, colnames(TreeCmp[[1]]))
            if(length(metric.column) == 0) {
                stop('Provided metric name is not found in the "TreeCmp" object')
            } else {
                TreeCmp.rows<-NULL
                for (i in 1:length.TreeCmp) {
                    TreeCmp.rows[i]<-length(TreeCmp[[i]][,metric.column])
                }
            }
        }
    }

    #plot
    if(class(plot) != 'logical'){
        stop('Plot is not logical')
    }

    #LaTeX
    if(class(LaTeX) != 'logical'){
        stop('LaTeX is not logical')
    } else {
        if(LaTeX == TRUE){
            require(xtable)
        }
    }

    #save.test
    if(class(save.test) != 'logical'){
        stop('Save.test is not logical')
    }

#FUNCTIONS

    FUN.data.table<-function(TreeCmp, metric, replicates.TreeCmp){
        #makes a data frame of all the replicates for one metric for all the comparisons (length must be length.TreeCmp*replicates.TreeCmp)
        data.table<-NULL
        metric.number<-which(names(TreeCmp[[1]]) == metric)

        for (n in 1:length.TreeCmp){
            data.table[[n]]<-TreeCmp[[n]][[metric.number]]
        }

        data.table<-as.data.frame(data.table)
        names(data.table)<-names(TreeCmp)

        return(data.table)
    }

    FUN.anova.data<-function(data.table, length.TreeCmp, replicates.TreeCmp) {
        #makes a factor vector and a values vector
        factors<-NULL
        for (n in 1:length.TreeCmp){
            factors<-c(factors, rep(names(TreeCmp)[n], replicates.TreeCmp))
        }

        values<-NULL
        for (n in 1:length.TreeCmp) {
            values<-c(values, data.table[[n]])
        }
        
        anova.data<-list(factors=factors, values=values)
        return(anova.data)

    }

    FUN.parametric<-function(anova.table, save.test){
        #Tests if the anova must be parametric or not
         
        #Test Normality
        normality<-shapiro.test(anova.data[[2]])
        p.normality<-normality[[2]]

        #IN DEVELOPEMENT {

        #Error in shapiro.test(anova.data[[2]]) : 
        #sample size must be between 3 and 5000

        #} IN DEVELOPEMENT



        #Test Homoscedasticity
        homoscedasticity<-bartlett.test(anova.data[[2]]~anova.data[[1]])
        p.homoscedasticity<-homoscedasticity[[3]]

        if(save.test == TRUE) {
            save.test<<-list(normality=normality, homoscedasticity=homoscedasticity)
        }

        #Choosing parametric or non-parametric test
        if(p.normality < 0.05){
            normality<-FALSE
        } else {
            normality<-TRUE
        }

        if(p.homoscedasticity < 0.05){
            homoscedasticity<-FALSE
        } else {
            homoscedasticity<-TRUE
        }

        if(normality == TRUE) {
            if(homoscedasticity == TRUE) {
                parametric<-TRUE
                cat("Test is parametric. \n")
            } else {
                parametric<-FALSE
                cat("Test is non-parametric. \n")
            }
        } else {
            parametric<-FALSE
            cat("Test is non-parametric.\n")
        } 
        return(parametric)
    }


#CALCULATING THE DIFFERENCE BETWEEN THE TREE COMPARISONS

    data.table<-FUN.data.table(TreeCmp, metric, replicates.TreeCmp)
    anova.data<-FUN.anova.data(data.table, length.TreeCmp, replicates.TreeCmp)
    parametric<-FUN.parametric(anova.data, save.test)


    if(parametric == TRUE) {
        #Test is parametric

        aov<-aov(values ~ factors, data=anova.data)
        anova<-summary(aov) #more variation among groups than within? null hypothesis that there is no difference among groups.
        pvalue<-anova[[1]][[5]][1]

        #If there posthoc difference
        if(pvalue < 0.05){
            posthoc<-TukeyHSD(aov)
        }

    } else {
        #Test is non-parametric

        #Transform the factors into numerical levels
        anova.data$factors<-as.factor(anova.data$factors)
        levels(anova.data$factors)<-c(seq(1:length(levels(anova.data$factors))))
        anova<-kruskal.test(values ~ factors, data=anova.data)
        pvalue<-anova[[3]]
        #If there posthoc difference
        if(pvalue < 0.05){

            #IN DEVELOPEMENT {

            require(pgirmess)
            posthoc<-kruskalmc(values ~ factors, data=anova.data)
            posthoc<-posthoc$dif.com

            #} IN DEVELOPEMENT
        }

    }



    #Plot (optional)
    if(plot == TRUE){
        if(pvalue < 0.05) {
            par( mfrow = c( 1, 2 ) )
            plot(posthoc, las=2)
            boxplot(data.table, ylab=metric, las=2, main="Data distribution")
        } else {
            boxplot(data.table, ylab=metric, las=2, main="Data distribution") 
        }
    }

#OUTPUT

    if(LaTeX == TRUE){
        TreeCmp.xtable<<-xtable(aov)
        cat('LaTeX anova table available in : \n TreeCmp.xtable',"\n")

        if(pvalue < 0.05){
            TreeCmp.xtables<<-list(anova=xtable(aov), posthoc=xtable(posthoc$factors))
            cat('LaTeX anova table available in : \n TreeCmp.xtables$anova',"\n")
            cat('LaTeX TukeyHSD table available in : \n TreeCmp.xtables$TuckeyHSD',"\n")
        }
    }

    if(save.test == FALSE){
        if(pvalue < 0.05){
            output<-list(anova=anova, posthoc=posthoc)
        } else {
            output<-anova
        }
    } else {
         if(pvalue < 0.05){
            output<-list(anova=anova, posthoc=posthoc, save.test=save.test)
        } else {
            output<-list(anova=anova, save.test=save.test)
        }       
    }
    return(output)

#End
}