function Xguess = LS_deconv(forwardFUN, backwardFUN, df, opts)
% LS_DECONV is an algorithm that performs projected gradient descent with
% exact line search for a Total Variation, L2 and L1-regularized non negative
% least squares problem. 
%
%   argmin_{x>=0} ||y-A(x)||_2^2 + lamb_TV_2*||TV(x)||_2^2 +
%   lamb_L2*||x||_2^2 + lamb_L1*||x||_1
%
% Input:
% forwardFUN...         function handle of the linear function A (formula above)
% backwardFUN...        function handle of the adjoint of A.
% df...                 single/double array representing A'(y).
% struct opts:
% opts.lamb_TV_L2...    1x3 array, lagrangian multiplier of the L2 norm of the Total
%                       Variation regularizer. For each spatial direction one 
%                       individual regularizer.
% opts.lamb_L1...       lagrangian multiplier for the L1 regularizer
% opts.lamb_L2...       lagrangian multiplier for the L2 regularizer
% opts.max_iter...      number of iterations.
%
% Output:
% Xguess...             The algorithms approximation of the solution of the
%                       abover problem.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin<4
    opts=struct;
end

if ~isfield(opts,'lamb_TV_L1')
    opts.lamb_TV_L1 = 0;
end
if ~isfield(opts,'lamb_TV_L2')
    opts.lamb_TV_L2 = [0 0 0];
end
if ~isfield(opts,'lamb_L1')
    opts.lamb_L1 = 0;
end
if ~isfield(opts,'lamb_L2')
    opts.lamb_L2 = 0;
end
if ~isfield(opts,'max_iter')
    opts.max_iter = 8;
end


disp('Running fast_deconv() with options:');
disp(opts);

if max(opts.lamb_TV_L2)
    if length(opts.lamb_TV_L2)==1
        opts.p=opts.lamb_TV_L2*[1,1,1];
    end
    filter=zeros(3,3,3);
    filter(2,2,[1 3])=opts.lamb_TV_L2(3);
    filter(2,[1 3],2)=opts.lamb_TV_L2(2);
    filter([1 3],2,2)=opts.lamb_TV_L2(1);
    filter(2,2,2)=-sum(opts.lamb_TV_L2);
    if isempty(opts.gpu_ids)
        lb_TV_L2 = @(X) convn(X,filter,'same');
    else
        lb_TV_L2 = @(X) convn(X,gpuArray(filter),'same');
    end
else
    lb_TV_L2 = @(X) 0;
end

if opts.lamb_L2
    lb_2 = @(X) opts.lamb_L2*X;
else
    lb_2 = @(X) 0;
end

Q = @(X) backwardFUN(forwardFUN(X)) + lb_TV_L2(X) + lb_2(X) ;
Xguess = df;
df = Q(df) - df + opts.lamb_L1;


for iter=1:opts.max_iter
    tic;
    passive=max(Xguess>0,df<0);
    df_=passive.*df;
    if opts.lamb_TV_L1*opts.lamb_TV_L2*opts.lamb_L2
        alpha=(df_(:)'*df_(:))/sum(sum(sum(df_.*Q(df_),1),2),3);
    else
        v = forwardFUN(df_);
        alpha=(df_(:)'*df_(:))/(v(:)'*v(:));
    end
    alpha(isnan(alpha))=0;
    alpha(isinf(alpha))=0;    
    df_=Xguess-alpha*df_;    
    df_(df_<0)=0;
    df=df+Q(df_-Xguess);
    Xguess=df_;
    ttime = toc;
    disp(['  Iteration ' num2str(iter) '/' num2str(opts.max_iter) ' took ' num2str(ttime) ' secs']);
end

end