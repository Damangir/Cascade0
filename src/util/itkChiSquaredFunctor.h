/*
 * Copyright (C) 2013 Soheil Damangir - All Rights Reserved
 * You may use and distribute, but not modify this code under the terms of the
 * Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
 * under the following conditions:
 *
 * Attribution — You must attribute the work in the manner specified by the
 * author or licensor (but not in any way that suggests that they endorse you
 * or your use of the work).
 * Noncommercial — You may not use this work for commercial purposes.
 * No Derivative Works — You may not alter, transform, or build upon this
 * work
 *
 * To view a copy of the license, visit
 * http://creativecommons.org/licenses/by-nc-nd/3.0/
 */
#ifndef __itkChiSquaredFunctor_h
#define __itkChiSquaredFunctor_h

#include "vnl/algo/vnl_chi_squared.h"

namespace itk
{
namespace Functor
{
template< class TInput, class TOutput >
class ChiSquaredFunctor
{
public:

  ChiSquaredFunctor()
    {
    m_DOF = 1;
    }
  virtual ~ChiSquaredFunctor()
    {
    }
  void SetDOF(const int _arg)
    {
    this->m_DOF = _arg;
    }

  bool operator!=(const ChiSquaredFunctor &) const
    {
    return false;
    }
  bool operator==(const ChiSquaredFunctor & other) const
    {
    return !(*this != other);
    }
  inline TOutput operator()(const TInput & A) const
    {

    double chiSquared = 0.0;

    if (A > 0.0)
      {
      chiSquared = vnl_chi_squared_cumulative(double(A), m_DOF);
      }
    else
      {
      chiSquared = -vnl_chi_squared_cumulative(double(-A), m_DOF);
      }

    return TOutput(chiSquared);
    }
private:
  int m_DOF;
};

} // end namespace Functor
} // end namespace itk

#endif
