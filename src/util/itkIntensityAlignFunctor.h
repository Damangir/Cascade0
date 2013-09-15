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
#ifndef __itkIntensityAlignFunctor_h
#define __itkIntensityAlignFunctor_h

namespace itk
{
namespace Functor
{
template< class TInput1, class TInput2 = TInput1, class TOutput = TInput1 >
class IntensityAlignFunctor
{
public:

  IntensityAlignFunctor()
    {
    m_Mean = 0;
    }
  virtual ~IntensityAlignFunctor()
    {
    }
  void SetMean(const TInput1 _arg)
    {
    this->m_Mean = _arg;
    }

  bool operator!=(const IntensityAlignFunctor &) const
    {
    return false;
    }
  bool operator==(const IntensityAlignFunctor & other) const
    {
    return !(*this != other);
    }
  inline TOutput operator()(const TInput1 & A, const TInput2 & B) const
    {
    TInput2 out;
    if (A - m_Mean > 0)
      {
      out = B;
      }
    else
      {
      out = -B;
      }
    out = (out + 1) / 2;
    return TOutput(out);
    }
private:
  TInput1 m_Mean;
};
} // end namespace Functor
} // end namespace itk

#endif
