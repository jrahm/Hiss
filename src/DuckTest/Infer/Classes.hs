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
        (functions, selfAssignments) <- mconcatMapM (walkFunctions st) body
        let topFunctions = addAllAttributes $ map (second fixForSelf) functions

        let retType = Scalar $ setTypeName clname $ mappend topFunctions selfAssignments


        maybeInitType <- mapM (inferTypeForFunction st) (findInit body)
        let (Functional args _) = fixForSelf $ fromMaybe (Functional [] retType) maybeInitType

        return $ Functional args retType

        where
              walkFunctions :: InternalState -> Statement e -> DuckTest e ([(String, PyType)], StructuralType)
              walkFunctions state ex@(Fun {fun_name=(Ident name _), fun_body=body}) = do
                    fnType <- inferTypeForFunction state ex
                    let newstate = stateUnderFunction fnType state
                    selfAssignments <- mconcatMapM (findSelfAssign newstate) (walkStatements ex)
                    return ([(name, fnType)], selfAssignments)
              walkFunctions _ _ = return ([], emptyType)


              functionType state ex@(Fun {fun_name=(Ident name _)}) = Just . (,) name <$> inferTypeForFunction state ex
              functionType _ _ = return Nothing

              findSelfAssign state (Assign [Dot (Var (Ident "self" _) _) (Ident att _) _] fromexpr _) = singletonType att <$> inferTypeForExpression state fromexpr
              findSelfAssign _ _ = return emptyType

              findInit =  foldl (\x stmt -> case stmt of
                                  (Fun {fun_name = (Ident "__init__" _)}) ->
                                      Just stmt
                                  _ -> x) Nothing

              {- Strip away the self argument -}
              fixForSelf (Functional (_:nonselfparams) ret) = Functional nonselfparams ret
              fixForSelf x = x

