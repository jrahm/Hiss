module DuckTest.Infer.Classes where

import DuckTest.Internal.Common

import DuckTest.Monad
import DuckTest.AST.Util
import DuckTest.AST.BinaryOperators
import DuckTest.Types

import qualified Data.Map as Map

import DuckTest.Infer.Functions
import DuckTest.Infer.Expression
import DuckTest.Internal.State

import Control.Arrow

inferTypeForClass :: InternalState -> Statement a -> DuckTest a PyType
inferTypeForClass st cls@(Class {class_body = body, class_name = (Ident clname _)})
    = do
        maybeInitType <- mapM (inferTypeForFunction st) (findInit body)

        let (Functional args _) = fixForSelf $ fromMaybe (Functional [] Any) maybeInitType
        let newst = addVariableType clname (Functional args $ Alpha clname Any) st

        (functions, Union selfAssignments) <- mconcatMapM (walkFunctions newst) body
        let topFunctions = fromList Nothing $ map (second fixForSelf) functions

        let (Union tmpType) = mappend (Union topFunctions) (Union selfAssignments)
        let retType = setTypeName clname $ rewireAlphas retType tmpType

        return $ Functional args retType

        where
              walkFunctions :: InternalState -> Statement e -> DuckTest e ([(String, PyType)], UnionType)
              walkFunctions state ex@(Fun {fun_name=(Ident name _), fun_body=body}) = do
                    fnType <- inferTypeForFunction state ex
                    let newstate = addVariableType clname (Functional [] $ Alpha clname Any) $ stateUnderFunction fnType state
                    (Union selfAssignments) <- mconcatMapM (Union <.< findSelfAssign newstate) (walkStatements ex)
                    return ([(name, fnType)], Union selfAssignments)
              walkFunctions _ _ = return ([], Union Void)

              rewireAlphas :: PyType -> PyType -> PyType
              rewireAlphas typ (Scalar str m) = Scalar str $ flip Map.map m $
                                                          \t -> case t of
                                                            Alpha name _ | name == clname -> Alpha name typ
                                                            _ -> t
              rewireAlphas _ t = t


              functionType state ex@(Fun {fun_name=(Ident name _)}) = Just . (,) name <$> inferTypeForFunction state ex
              functionType _ _ = return Nothing

              findSelfAssign state (Assign [Dot (Var (Ident "self" _) _) (Ident att _) _] fromexpr _) =
                case fromexpr of
                    None _ -> return $ singleton att  Void
                    _ -> singleton att <$> inferTypeForExpression state fromexpr
              findSelfAssign _ _ = return Void

              findInit =  foldl (\x stmt -> case stmt of
                                  (Fun {fun_name = (Ident "__init__" _)}) ->
                                      Just stmt
                                  _ -> x) Nothing

              {- Strip away the self argument -}
              fixForSelf (Functional (_:nonselfparams) ret) = Functional nonselfparams ret
              fixForSelf x = x

