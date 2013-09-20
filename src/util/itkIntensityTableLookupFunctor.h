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
#ifndef __itkIntensityTableLookupFunctor_h
#define __itkIntensityTableLookupFunctor_h

#include <utility>
#include <iterator>
#include <vector>
#include <algorithm>

namespace itk
{

template< typename TInput, typename TOutput >
class IntensityTableLookupFunctor
{
public:
  typedef std::pair< TInput, TOutput > LookupRowType;
  typedef std::vector< LookupRowType > LookupTableType;

  IntensityTableLookupFunctor()
    {
    }
  ~IntensityTableLookupFunctor()
    {
    }
  void AddLookupRow(const TInput & x, const TOutput & y)
    {
    m_Table.push_back(LookupRowType(x, y));
    std::sort(m_Table.begin(), m_Table.end());
    }
  bool operator!=(const IntensityTableLookupFunctor & other) const
    {
    if (std::equal(m_Table.begin(), m_Table.end(), other.m_Table.begin()))
      {
      return true;
      }
    return false;
    }

  bool operator==(const IntensityTableLookupFunctor & other) const
    {
    return !(*this != other);
    }

  inline TOutput operator()(const TInput & x) const
    {
    TOutput lookup;
    if (m_Table.size() < 2)
      {
      lookup = x;
      }
    else
      {
      int index = 1;

      for (; index < (m_Table.size() - 1); index++)
        if (x < m_Table[index].first) break;

      const double slope = (m_Table[index].second - m_Table[index - 1].second)
          / (m_Table[index].first - m_Table[index - 1].first);

      lookup = slope * (x - m_Table[index].first) + m_Table[index].second;
      }

    return lookup;
    }
  void Print() const
    {
    for (int i = 0; i < m_Table.size(); i++)
      {
      std::cout << m_Table[i].first << "--->" << m_Table[i].second << std::endl;
      }

    }
private:
  LookupTableType m_Table;
};

}

#endif
